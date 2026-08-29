"""
Local end-of-interval instant of a TMY3 row. The timestamp is written directly,
so `01:00` is the hour ending at 01:00. This is not EPW's encoding.
"""
function tmy3_local_stamp(y::Int, mo::Int, d::Int, hour::Int, minute::Int)
    1 <= hour <= 24 || throw(ArgumentError("TMY3 hour $hour is outside 1:24"))
    0 <= minute < 60 || throw(ArgumentError("TMY3 minute $minute is outside 0:59"))
    return DateTime(y, mo, d) + Hour(hour) + Minute(minute)
end

"""Column name in the file, canonical name, and unit conversion."""
const TMY3_MAPPED = (
    ("GHI (W/m^2)", :ghi, identity),
    ("DNI (W/m^2)", :dni, identity),
    ("DHI (W/m^2)", :dhi, identity),
    ("Dry-bulb (C)", :temp_air, identity),
    ("RHum (%)", :relative_humidity, identity),
    ("Pressure (mbar)", :pressure, x -> x * 100),   # mbar -> Pa
    ("Wdir (degrees)", :wind_direction, identity),
    ("Wspd (m/s)", :wind_speed, identity),
    ("Pwat (cm)", :precipitable_water, identity),   # already cm
    ("Alb (unitless)", :albedo, identity),
)

"""
    read_tmy3(path; T = Float64, coerce_year = nothing) -> MeteoData{T}

Read an NREL TMY3 file.

Two header lines precede the data, carrying station metadata and then column
names. Timestamps are `MM/DD/YYYY` plus an `HH:MM` whose hour runs 1..24 and
labels the end of the interval, and they are converted to UTC using the declared
offset. Note that `01:00` means the hour ending at 01:00, which is not how EPW
encodes the same instant.

Irradiance is already power here, unlike EPW, where it is energy accumulated over
the record. No interval scaling is applied.

Every column without a canonical name is kept in `meta.extra` under its name as
written in the file. That includes the `source` and `uncert (%)` columns.

Parsing never rejects. Use [`validate`](@ref) to inspect what was read.

`coerce_year` rewrites every year field before timestamps are built, for files
that stitch months from different years. The originals are kept in
`meta.extra[:source_years]`.
"""
function read_tmy3(path::AbstractString; T::Type = Float64, coerce_year = nothing)
    lines = readlines(path)
    length(lines) > 2 || throw(ArgumentError("$path has no TMY3 data rows"))

    station_fields = split(lines[1], ',')
    length(station_fields) >= 7 ||
        throw(ArgumentError("$path has a malformed TMY3 station line"))
    usaf = strip(station_fields[1])
    station = strip(station_fields[2])
    tz_hours = parse(Float64, station_fields[4])
    latitude = parse(Float64, station_fields[5])
    longitude = parse(Float64, station_fields[6])
    altitude = parse(Float64, station_fields[7])

    header = strip.(split(lines[2], ','))
    index = Dict(name => i for (i, name) in enumerate(header))

    rows = @view lines[3:end]
    n = length(rows)
    fields = [strip.(split(row, ',')) for row in rows]
    for (i, f) in enumerate(fields)
        length(f) == length(header) || throw(
            ArgumentError(
                "$path row $i has $(length(f)) fields, expected $(length(header))",
            ),
        )
    end

    date_at = get(index, "Date (MM/DD/YYYY)", 1)
    time_at = get(index, "Time (HH:MM)", 2)

    source_years = Vector{Int}(undef, n)
    local_time = Vector{DateTime}(undef, n)
    for i = 1:n
        month_s, day_s, year_s = split(fields[i][date_at], '/')
        hour_s, minute_s = split(fields[i][time_at], ':')
        source_years[i] = parse(Int, year_s)
        y = coerce_year === nothing ? source_years[i] : Int(coerce_year)
        local_time[i] = tmy3_local_stamp(
            y,
            parse(Int, month_s),
            parse(Int, day_s),
            parse(Int, hour_s),
            parse(Int, minute_s),
        )
    end

    utc_offset = Minute(round(Int, tz_hours * 60))
    time = local_time .- utc_offset

    names = Symbol[]
    vectors = Vector{T}[]
    mapped_columns = Set{String}([String(header[date_at]), String(header[time_at])])
    for (column_name, name, convert) in TMY3_MAPPED
        haskey(index, column_name) || continue
        at = index[column_name]
        push!(mapped_columns, column_name)
        column = Vector{T}(undef, n)
        for i = 1:n
            column[i] = T(convert(parse(Float64, fields[i][at])))
        end
        push!(names, name)
        push!(vectors, column)
    end
    isempty(names) &&
        throw(ArgumentError("$path has none of the expected TMY3 data columns"))

    extra = Dict{Symbol,Any}(:usaf => String(usaf))
    for (i, column_name) in enumerate(header)
        String(column_name) in mapped_columns && continue
        extra[Symbol(column_name)] = [String(f[i]) for f in fields]
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
        interval = canonical_interval(Hour(1)),
        source = :tmy3,
        origin = abspath(path),
        retrieved = unix2datetime(mtime(path)),
        content_hash = content_hash(path),
        station = isempty(station) ? nothing : String(station),
        extra,
    )

    data = NamedTuple{Tuple(names)}(Tuple(vectors))
    return MeteoData(time, data, meta)
end
