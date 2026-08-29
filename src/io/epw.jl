# EnergyPlus Weather (EPW).
#
# Eight header lines, then comma-separated data rows of 35 fields. The header
# carries coordinates, elevation, UTC offset and the record interval, so the
# reader never asks the user to restate what the file already says.

"""Index, canonical name and unit conversion for the fields we map."""
const EPW_MAPPED = (
    (7, :temp_air, identity),                    # °C
    (9, :relative_humidity, identity),           # %
    (10, :pressure, identity),                   # Pa
    (14, :ghi, identity),                        # Wh/m² -> W/m², see below
    (15, :dni, identity),
    (16, :dhi, identity),
    (21, :wind_direction, identity),             # degrees
    (22, :wind_speed, identity),                 # m/s
    (29, :precipitable_water, x -> x / 10),      # mm -> cm
    (33, :albedo, identity),                     # dimensionless
)

"""Irradiance fields are accumulated energy and need the interval scaling."""
const EPW_IRRADIANCE = (:ghi, :dni, :dhi)

"""Names for the data fields we do not map, so they can be kept in `extra`."""
const EPW_UNMAPPED = Dict(
    6 => :data_source_and_uncertainty_flags,
    8 => :dew_point_temperature,
    11 => :extraterrestrial_horizontal_radiation,
    12 => :extraterrestrial_direct_normal_radiation,
    13 => :horizontal_infrared_radiation,
    17 => :global_horizontal_illuminance,
    18 => :direct_normal_illuminance,
    19 => :diffuse_horizontal_illuminance,
    20 => :zenith_luminance,
    23 => :total_sky_cover,
    24 => :opaque_sky_cover,
    25 => :visibility,
    26 => :ceiling_height,
    27 => :present_weather_observation,
    28 => :present_weather_codes,
    30 => :aerosol_optical_depth,
    31 => :snow_depth,
    32 => :days_since_last_snowfall,
    34 => :liquid_precipitation_depth,
    35 => :liquid_precipitation_quantity,
)

const EPW_HEADER_KEYS = (
    :location,
    :design_conditions,
    :typical_extreme_periods,
    :ground_temperatures,
    :holidays_dst,
    :comments_1,
    :comments_2,
    :data_periods,
)

"""
    epw_local_stamp(year, month, day, hour, minute) -> DateTime

The local end-of-interval instant a row describes.

EPW hour `h` runs 1..24 and covers `(h-1):00` to `h:00`; the minute field runs
1..60 within that hour. Counting from the start of hour `h-1` handles the
hour-24 rollover into the next day and sub-hourly records with one rule.
"""
function epw_local_stamp(y::Int, m::Int, d::Int, hour::Int, minute::Int)
    1 <= hour <= 24 || throw(ArgumentError("EPW hour $hour is outside 1:24"))
    0 <= minute <= 60 || throw(ArgumentError("EPW minute $minute is outside 0:60"))
    return DateTime(y, m, d) + Hour(hour - 1) + Minute(minute)
end

"""
    read_epw(path; T = Float64, coerce_year = nothing) -> MeteoData{T}

Read an EnergyPlus Weather file.

Metadata comes from the file's own header. Timestamps are converted to UTC using
the offset the header declares — EPW is written in local *standard* time, so a
file spanning a daylight-saving transition still yields uniform UTC.

Nothing is discarded: the seven non-`LOCATION` header lines and every data field
without a canonical name are kept in `meta.extra`.

Parsing never rejects. A file with duplicate or missing records is returned as
found; use [`validate`](@ref) to learn about it.

`coerce_year` rewrites every year field before timestamps are built, for
TMY-style files that stitch months from different years. The originals are kept
in `meta.extra[:source_years]`.
"""
function read_epw(path::AbstractString; T::Type = Float64, coerce_year = nothing)
    lines = readlines(path)
    length(lines) > 8 || throw(ArgumentError("$path has no EPW data rows"))

    extra = Dict{Symbol, Any}()
    for (i, key) in enumerate(EPW_HEADER_KEYS)
        key === :location && continue
        extra[key] = lines[i]
    end

    location = split(lines[1], ',')
    length(location) >= 10 ||
        throw(ArgumentError("$path has a malformed LOCATION line"))
    station = strip(location[2])
    latitude = parse(Float64, location[7])
    longitude = parse(Float64, location[8])
    tz_hours = parse(Float64, location[9])
    altitude = parse(Float64, location[10])

    periods = split(lines[8], ',')
    length(periods) >= 3 ||
        throw(ArgumentError("$path has a malformed DATA PERIODS line"))
    records_per_hour = parse(Int, strip(periods[3]))
    records_per_hour >= 1 || throw(
        ArgumentError("$path declares $records_per_hour records per hour"),
    )
    interval = canonical_interval(Millisecond(3_600_000 ÷ records_per_hour))

    rows = @view lines[9:end]
    n = length(rows)
    fields = [split(row, ',') for row in rows]
    for (i, f) in enumerate(fields)
        length(f) >= 35 || throw(
            ArgumentError(
                "$path row $i has $(length(f)) fields, expected at least 35",
            ),
        )
    end

    source_years = [parse(Int, f[1]) for f in fields]
    years = coerce_year === nothing ? source_years : fill(Int(coerce_year), n)
    local_time = Vector{DateTime}(undef, n)
    for i in 1:n
        f = fields[i]
        local_time[i] = epw_local_stamp(
            years[i],
            parse(Int, f[2]),
            parse(Int, f[3]),
            parse(Int, f[4]),
            parse(Int, f[5]),
        )
    end

    utc_offset = Minute(round(Int, tz_hours * 60))
    time = local_time .- utc_offset

    # EPW irradiance is Wh/m² accumulated over one record, so a quarter-hour file
    # holds a quarter of the energy of an hourly one for the same power.
    irradiance_scale = T(records_per_hour)

    names = Symbol[]
    vectors = Vector{T}[]
    for (idx, name, convert) in EPW_MAPPED
        column = Vector{T}(undef, n)
        scale = name in EPW_IRRADIANCE ? irradiance_scale : one(T)
        for i in 1:n
            column[i] = T(convert(parse(Float64, fields[i][idx]))) * scale
        end
        push!(names, name)
        push!(vectors, column)
    end

    for (idx, name) in sort!(collect(EPW_UNMAPPED); by = first)
        extra[name] = [strip(f[idx]) for f in fields]
    end
    if coerce_year !== nothing
        extra[:coerced_year] = Int(coerce_year)
        extra[:source_years] = source_years
    end

    meta = MeteoMeta(;
        latitude,
        longitude,
        altitude,
        utc_offset,
        label = RightLabeled(),
        interval,
        source = :epw,
        origin = abspath(path),
        retrieved = unix2datetime(mtime(path)),
        content_hash = content_hash(path),
        station = isempty(station) ? nothing : String(station),
        extra,
    )

    data = NamedTuple{Tuple(names)}(Tuple(vectors))
    return MeteoData(time, data, meta)
end
