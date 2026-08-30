@testsnippet ClosureFixture begin
    using Dates
    fixture(name) = joinpath(@__DIR__, "fixtures", name)

    function series(nt; times = nothing, start = DateTime(2020, 6, 20), interval = Hour(1))
        n = length(first(nt))
        meta = PVMeteo.MeteoMeta(;
            latitude = 52.1,
            longitude = 5.18,
            altitude = 2.0,
            utc_offset = Minute(0),
            label = PVMeteo.RightLabeled(),
            interval = interval,
            source = :test,
            origin = "memory",
            retrieved = DateTime(2026, 1, 1),
            content_hash = UInt64(0),
        )
        t = times === nothing ? collect(start:interval:(start+interval*(n-1))) : times
        return PVMeteo.MeteoData(t, nt, meta)
    end

    function closure_cosz()
        lines = readlines(fixture("closure_cosz.csv"))
        return parse.(Float64, lines[2:end])
    end

    named(flags, name) = filter(f -> f.check === name, flags)
    has(flags, name) = !isempty(named(flags, name))
    checks(flags) = Set(f.check for f in flags)
end

@testitem "a consistent file closes" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = PVMeteo.read_epw(fixture("closure_good.epw"))
    flags = PVMeteo.check_closure(md, closure_cosz())
    @test isempty(flags)
end

@testitem "inflated DHI breaks closure" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = PVMeteo.read_epw(fixture("closure_bad.epw"))
    flags = PVMeteo.check_closure(md, closure_cosz())
    f = only(named(flags, :closure))
    @test f.severity == :error
    @test f.indices == [12, 13, 14, 36, 37, 38]
    @test f.column === :ghi
end

@testitem "a loose tolerance forgives it" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = PVMeteo.read_epw(fixture("closure_bad.epw"))
    @test isempty(PVMeteo.check_closure(md, closure_cosz(); tol = 0.25))
end

@testitem "GHI at night is a warning" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = series((; ghi = [40.0], dni = [0.0], dhi = [40.0]))
    flags = PVMeteo.check_closure(md, [-0.5])
    f = only(named(flags, :night_nonzero))
    @test f.severity == :warn
    @test f.indices == [1]
    @test !has(flags, :closure)
end

@testitem "a dark night is quiet" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = series((; ghi = [0.0], dni = [0.0], dhi = [0.0]))
    @test isempty(PVMeteo.check_closure(md, [-0.5]))
end

@testitem "closure needs all three" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = series((; ghi = [400.0]))
    f = only(PVMeteo.check_closure(md, [0.8]))
    @test f.check === :closure_unavailable
    @test f.severity == :info
    @test occursin("dni", f.detail) && occursin("dhi", f.detail)
end

@testitem "closure needs a matching cosz" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = series((; ghi = [400.0], dni = [500.0], dhi = [50.0]))
    @test_throws DimensionMismatch PVMeteo.check_closure(md, [0.8, 0.8])
end

@testitem "validate reports missing cosz" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = PVMeteo.read_epw(fixture("closure_bad.epw"))
    report = PVMeteo.validate(md)
    f = only(filter(f -> f.check === :skipped_needs_cosz, report.flags))
    @test f.severity == :info
    @test report.n_records == length(md.time)
    @test !(:closure in checks(report.flags))
    @test :constant_run in checks(report.flags)
end

@testitem "validate runs every check" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = PVMeteo.read_epw(fixture("closure_bad.epw"))
    report = PVMeteo.validate(md; cosz = closure_cosz())
    found = checks(report.flags)
    @test :closure in found
    @test :constant_run in found
    @test !(:skipped_needs_cosz in found)
end

@testitem "validate covers time and limits" tags=[:unit, :fast] setup=[ClosureFixture] begin
    t = DateTime(2020, 6, 20, 12)
    md = series((; ghi = [5000.0, 5000.0]); times = [t, t])
    found = checks(PVMeteo.validate(md; cosz = [0.9, 0.9]).flags)
    @test :duplicate_ts in found
    @test :physical_limit in found
    @test :closure_unavailable in found
end

@testitem "validate does not mutate" tags=[:unit, :fast] setup=[ClosureFixture] begin
    md = PVMeteo.read_epw(fixture("closure_bad.epw"))
    before = deepcopy(md)
    PVMeteo.validate(md; cosz = closure_cosz())
    @test md.time == before.time
    @test md.data == before.data
    @test md.meta.history == before.meta.history
end
