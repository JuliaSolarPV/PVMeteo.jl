@testsnippet TMY3Fixture begin
    using Dates
    fixture(name) = joinpath(@__DIR__, "fixtures", name)
end

@testitem "read_tmy3 parses the station header" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    md = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    @test md.meta.latitude == 52.10
    @test md.meta.longitude == 5.18
    @test md.meta.altitude == 2.0
    @test md.meta.utc_offset == Minute(-300)
    @test md.meta.station == "De Bilt"
    @test md.meta.source == :tmy3
    @test md.meta.extra[:usaf] == "062600"
end

@testitem "read_tmy3 is right-labelled hourly" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    md = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    @test md.meta.label === PVMeteo.RightLabeled()
    @test md.meta.interval === Hour(1)
end

@testitem "read_tmy3 yields clean UTC timestamps" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    md = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    @test length(md.time) == 72
    @test issorted(md.time, lt = <)
    @test allunique(md.time)
    @test all(==(Hour(1)), diff(md.time))
    # 01:00 local at UTC-5 is 06:00 UTC.
    @test md.time[1] == DateTime(2020, 6, 20, 6)
end

@testitem "read_tmy3 maps the canonical columns" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    md = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    for name in (:ghi, :dni, :dhi, :temp_air, :relative_humidity, :pressure,
                 :wind_direction, :wind_speed, :precipitable_water, :albedo)
        @test PVMeteo.hascolumn(md, name)
    end
end

@testitem "read_tmy3 converts mbar to Pa" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    md = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    # TMY3 stores whole mbar, so 1013 mbar is 101300 Pa exactly.
    @test all(≈(101_300.0), PVMeteo.pressure(md))
end

@testitem "read_tmy3 leaves W/m2 alone" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    # Unlike EPW, TMY3 irradiance is already power. No interval scaling.
    md = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    raw = maximum(
        parse(Float64, split(l, ',')[5]) for
        l in readlines(fixture("minimal_tmy3.csv"))[3:end]
    )
    @test maximum(PVMeteo.ghi(md)) == raw
end

@testitem "read_tmy3 keeps precipitable water in cm" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    md = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    @test all(≈(1.5), PVMeteo.precipitable_water(md))
end

@testitem "read_tmy3 keeps source and uncertainty" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    md = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    e = md.meta.extra
    @test haskey(e, Symbol("GHI uncert (%)"))
    @test haskey(e, Symbol("GHI source"))
    @test haskey(e, Symbol("ETR (W/m^2)"))
    @test length(e[Symbol("GHI uncert (%)")]) == length(md.time)
    @test all(==("8"), e[Symbol("GHI uncert (%)")])
end

@testitem "read_tmy3 hashes the source bytes" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    a = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    @test a.meta.content_hash == PVMeteo.content_hash(fixture("minimal_tmy3.csv"))
    @test isempty(a.meta.lineage)
end

@testitem "read_tmy3 honours the element type" tags=[:unit, :fast] setup=[TMY3Fixture] begin
    md64 = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    md32 = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"); T = Float32)
    @test md32 isa PVMeteo.MeteoData{Float32}
    @test PVMeteo.ghi(md32) ≈ PVMeteo.ghi(md64) rtol = eps(Float32)
end

@testitem "the two stamp encodings differ" tags=[:unit, :fast] begin
    using Dates
    # EPW splits an instant into hour 1..24 plus a minute 1..60 counted inside
    # that hour; TMY3 writes the instant itself. Both describe the same moment.
    @test PVMeteo.epw_local_stamp(2020, 6, 20, 1, 60) == DateTime(2020, 6, 20, 1)
    @test PVMeteo.tmy3_local_stamp(2020, 6, 20, 1, 0) == DateTime(2020, 6, 20, 1)

    # Hour 24 rolls into midnight of the next day under both.
    @test PVMeteo.epw_local_stamp(2020, 6, 20, 24, 60) == DateTime(2020, 6, 21)
    @test PVMeteo.tmy3_local_stamp(2020, 6, 20, 24, 0) == DateTime(2020, 6, 21)

    # Sub-hourly EPW.
    @test PVMeteo.epw_local_stamp(2020, 6, 20, 2, 15) == DateTime(2020, 6, 20, 1, 15)

    @test_throws ArgumentError PVMeteo.epw_local_stamp(2020, 6, 20, 0, 60)
    @test_throws ArgumentError PVMeteo.epw_local_stamp(2020, 6, 20, 25, 60)
    @test_throws ArgumentError PVMeteo.tmy3_local_stamp(2020, 6, 20, 1, 60)
end
