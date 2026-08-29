@testsnippet LimitFixture begin
    using Dates
    fixture(name) = joinpath(@__DIR__, "fixtures", name)

    function series(nt; start = DateTime(2020, 6, 21), interval = Hour(1))
        n = length(first(nt))
        meta = PVMeteo.MeteoMeta(;
            latitude = 52.0,
            longitude = 4.9,
            altitude = 10.0,
            utc_offset = Minute(0),
            label = PVMeteo.LeftLabeled(),
            interval = interval,
            source = :test,
            origin = "memory",
            retrieved = DateTime(2026, 1, 1),
            content_hash = UInt64(0),
        )
        t = collect(start:interval:(start + interval * (n - 1)))
        return PVMeteo.MeteoData(t, nt, meta)
    end

    function closure_cosz()
        lines = readlines(fixture("closure_cosz.csv"))
        return parse.(Float64, lines[2:end])
    end

    named(flags, name) = filter(f -> f.check === name, flags)
    has(flags, name) = !isempty(named(flags, name))
end

@testitem "the solar constant varies over the year" tags=[:unit, :fast] begin
    jan = PVMeteo.extraterrestrial_normal(3)
    jul = PVMeteo.extraterrestrial_normal(185)
    @test jan > jul                      # perihelion in early January
    @test 1400 < jan < 1420
    @test 1315 < jul < 1330
end

@testitem "an impossible value is an error" tags=[:unit, :fast] setup=[LimitFixture] begin
    md = series((; ghi = [5000.0, 100.0]))
    flags = PVMeteo.check_limits(md, [0.9, 0.9])
    pl = only(named(flags, :physical_limit))
    @test pl.severity == :error
    @test pl.column === :ghi
    @test pl.indices == [1]
end

@testitem "a rare value is only a warning" tags=[:unit, :fast] setup=[LimitFixture] begin
    mu = 0.877
    S = PVMeteo.extraterrestrial_normal(173)
    between = (S * 1.2 * mu^1.2 + 50) + 10.0     # over rare, under possible
    md = series((; ghi = [between]))
    flags = PVMeteo.check_limits(md, [mu])
    @test !has(flags, :physical_limit)
    rare = only(named(flags, :extremely_rare))
    @test rare.severity == :warn
    @test rare.indices == [1]
end

@testitem "thermal offset is tolerated" tags=[:unit, :fast] setup=[LimitFixture] begin
    # A pyranometer reading slightly below zero at night is a healthy instrument.
    md = series((; ghi = [-3.0, -8.0]))
    flags = PVMeteo.check_limits(md, [0.0, 0.0])
    @test only(named(flags, :physical_limit)).indices == [2]
end

@testitem "clean data raises nothing" tags=[:unit, :fast] setup=[LimitFixture] begin
    md = PVMeteo.read_epw(fixture("closure_good.epw"))
    @test isempty(PVMeteo.check_limits(md, closure_cosz()))
end

@testitem "absent columns are skipped" tags=[:unit, :fast] setup=[LimitFixture] begin
    md = series((; temp_air = [20.0, 21.0]))
    @test isempty(PVMeteo.check_limits(md, [0.9, 0.9]))
end

@testitem "cosz length must match" tags=[:unit, :fast] setup=[LimitFixture] begin
    md = series((; ghi = [1.0, 2.0, 3.0]))
    @test_throws DimensionMismatch PVMeteo.check_limits(md, [0.9, 0.9])
end

@testitem "each component gets its own bound" tags=[:unit, :fast] setup=[LimitFixture] begin
    # DNI is bounded by Sa itself, so a value under Sa is fine while the same
    # value in DHI is impossible.
    S = PVMeteo.extraterrestrial_normal(173)
    md = series((; dni = [S - 50], dhi = [S - 50]))
    flags = PVMeteo.check_limits(md, [0.3])
    cols = sort([f.column for f in named(flags, :physical_limit)])
    @test cols == [:dhi]
end

@testitem "a stuck sensor is flagged" tags=[:unit, :fast] setup=[LimitFixture] begin
    md = series((; temp_air = vcat(fill(12.0, 8), [13.0, 14.0])))
    run = only(PVMeteo.check_constant_runs(md))
    @test run.check === :constant_run
    @test run.severity == :warn
    @test run.column === :temp_air
    @test run.indices == collect(1:8)
end

@testitem "night zeros are not a stuck sensor" tags=[:unit, :fast] setup=[LimitFixture] begin
    md = series((; ghi = vcat(fill(0.0, 12), [50.0, 200.0])))
    @test isempty(PVMeteo.check_constant_runs(md))
end

@testitem "a short run is left alone" tags=[:unit, :fast] setup=[LimitFixture] begin
    md = series((; temp_air = vcat(fill(12.0, 5), [13.0])))
    @test isempty(PVMeteo.check_constant_runs(md))
    @test !isempty(PVMeteo.check_constant_runs(md; minimum_run = 5))
end

@testitem "zeros still count off the sky" tags=[:unit, :fast] setup=[LimitFixture] begin
    # Only the irradiance columns get the night exemption.
    md = series((; wind_speed = fill(0.0, 10)))
    @test only(PVMeteo.check_constant_runs(md)).column === :wind_speed
end
