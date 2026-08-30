@testsnippet EPWFixture begin
    using Dates
    fixture(name) = joinpath(@__DIR__, "fixtures", name)
end

@testitem "read_epw parses the LOCATION header" tags=[:unit, :fast] setup=[EPWFixture] begin
    md = PVMeteo.read_epw(fixture("minimal.epw"))
    @test md.meta.latitude == 52.10
    @test md.meta.longitude == 5.18
    @test md.meta.altitude == 2.0
    @test md.meta.utc_offset == Minute(60)
    @test md.meta.station == "De Bilt"
    @test md.meta.source == :epw
    @test endswith(md.meta.origin, "minimal.epw")
end

@testitem "read_epw is right-labelled hourly" tags=[:unit, :fast] setup=[EPWFixture] begin
    md = PVMeteo.read_epw(fixture("minimal.epw"))
    @test md.meta.label === PVMeteo.RightLabeled()
    @test md.meta.interval === Hour(1)
end

@testitem "read_epw yields clean UTC timestamps" tags=[:unit, :fast] setup=[EPWFixture] begin
    md = PVMeteo.read_epw(fixture("minimal.epw"))
    @test length(md.time) == 72
    @test issorted(md.time, lt = <)
    @test allunique(md.time)
    @test all(==(Hour(1)), diff(md.time))
    # 01:00 local at UTC+1 is midnight UTC.
    @test md.time[1] == DateTime(2020, 6, 20, 0)
    @test md.time[end] == DateTime(2020, 6, 22, 23)
end

@testitem "read_epw maps the canonical columns" tags=[:unit, :fast] setup=[EPWFixture] begin
    md = PVMeteo.read_epw(fixture("minimal.epw"))
    for name in (
        :ghi,
        :dni,
        :dhi,
        :temp_air,
        :relative_humidity,
        :pressure,
        :wind_direction,
        :wind_speed,
        :precipitable_water,
        :albedo,
    )
        @test PVMeteo.hascolumn(md, name)
    end
end

@testitem "read_epw returns SI units" tags=[:unit, :fast] setup=[EPWFixture] begin
    md = PVMeteo.read_epw(fixture("minimal.epw"))
    @test all(≈(101_325.0), PVMeteo.pressure(md))          # Pa, not mbar
    @test all(≈(1.5), PVMeteo.precipitable_water(md))      # cm, from 15 mm
    @test all(≈(0.2), PVMeteo.albedo(md))
    @test maximum(PVMeteo.ghi(md)) > 500                   # W/m2 at 52N in June
    @test maximum(PVMeteo.ghi(md)) < 1400
    @test 10 <= minimum(PVMeteo.temp_air(md)) <= 25
end

@testitem "read_epw scales sub-hourly irradiance" tags=[:unit, :fast] setup=[EPWFixture] begin
    # EPW irradiance is Wh/m2 accumulated over the record. A 15-minute file holds
    # a quarter of the energy per record, so W/m2 must come out the same as hourly.
    hourly = PVMeteo.read_epw(fixture("minimal.epw"))
    quarter = PVMeteo.read_epw(fixture("subhourly.epw"))
    @test quarter.meta.interval === Minute(15)
    @test length(quarter.time) == 96
    @test all(==(Minute(15)), diff(quarter.time))
    @test maximum(PVMeteo.ghi(quarter)) ≈ maximum(PVMeteo.ghi(hourly)) rtol = 0.02
end

@testitem "read_epw keeps what it cannot map" tags=[:unit, :fast] setup=[EPWFixture] begin
    md = PVMeteo.read_epw(fixture("minimal.epw"))
    e = md.meta.extra
    for k in (
        :design_conditions,
        :typical_extreme_periods,
        :ground_temperatures,
        :holidays_dst,
        :comments_1,
        :comments_2,
        :data_periods,
    )
        @test haskey(e, k)
    end
    @test occursin("Synthetic fixture", e[:comments_1])
    # Unmapped data fields survive as columns of their own.
    @test haskey(e, :dew_point_temperature)
    @test length(e[:dew_point_temperature]) == length(md.time)
    @test haskey(e, :horizontal_infrared_radiation)
    @test haskey(e, :aerosol_optical_depth)
    @test haskey(e, :data_source_and_uncertainty_flags)
end

@testitem "read_epw hashes the source bytes" tags=[:unit, :fast] setup=[EPWFixture] begin
    a = PVMeteo.read_epw(fixture("minimal.epw"))
    b = PVMeteo.read_epw(fixture("minimal.epw"))
    @test a.meta.content_hash == b.meta.content_hash
    @test a.meta.content_hash == PVMeteo.content_hash(fixture("minimal.epw"))
    c = PVMeteo.read_epw(fixture("closure_good.epw"))
    @test c.meta.content_hash != a.meta.content_hash
    @test isempty(a.meta.history)
end

@testitem "read_epw honours the element type" tags=[:unit, :fast] setup=[EPWFixture] begin
    md64 = PVMeteo.read_epw(fixture("minimal.epw"))
    md32 = PVMeteo.read_epw(fixture("minimal.epw"); T = Float32)
    @test md32 isa PVMeteo.MeteoData{Float32}
    @test PVMeteo.ghi(md32) ≈ PVMeteo.ghi(md64) rtol = eps(Float32)
    @test md32.time == md64.time
end

@testitem "read_epw crosses DST cleanly" tags=[:unit, :fast] setup=[EPWFixture] begin
    # EPW is written in local standard time, so a file spanning a transition must
    # still parse to uniform UTC with no duplicate and no missing record.
    for name in ("dst_spring.epw", "dst_autumn.epw")
        md = PVMeteo.read_epw(fixture(name))
        @test allunique(md.time)
        @test all(==(Hour(1)), diff(md.time))
        @test length(md.time) == 72
    end
end

@testitem "read_epw does not repair a broken file" tags=[:unit, :fast] setup=[EPWFixture] begin
    # Parsing reports what it found. It never rejects or silently fixes.
    md = PVMeteo.read_epw(fixture("dst_duplicate.epw"))
    @test length(md.time) == 73
    @test !allunique(md.time)
    gapped = PVMeteo.read_epw(fixture("gap.epw"))
    @test length(gapped.time) == 68
    @test maximum(diff(gapped.time)) == Hour(5)
end

@testitem "read_epw can coerce the year" tags=[:unit, :fast] setup=[EPWFixture] begin
    md = PVMeteo.read_epw(fixture("minimal.epw"); coerce_year = 2001)
    @test all(t -> year(t) == 2001, md.time[2:(end-1)])
    @test md.meta.extra[:coerced_year] == 2001
    @test md.meta.extra[:source_years] == fill(2020, 72)
end
