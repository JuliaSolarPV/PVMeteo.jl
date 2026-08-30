@testsnippet RelabelFixture begin
    using Dates
    fixture(name) = joinpath(@__DIR__, "fixtures", name)

    const LABELS = (PVMeteo.LeftLabeled(), PVMeteo.CenterLabeled(), PVMeteo.RightLabeled())

    function series(; label = PVMeteo.LeftLabeled(), interval = Hour(1), n = 4)
        meta = PVMeteo.MeteoMeta(;
            latitude = 52.0,
            longitude = 4.9,
            altitude = 10.0,
            utc_offset = Minute(0),
            label = label,
            interval = interval,
            source = :test,
            origin = "memory",
            retrieved = DateTime(2026, 1, 1),
            content_hash = UInt64(0),
        )
        start = DateTime(2020, 6, 20)
        t = collect(start:interval:(start+interval*(n-1)))
        return PVMeteo.MeteoData(t, (; ghi = collect(1.0:n)), meta)
    end
end

@testitem "left to right shifts forward" tags=[:unit, :fast] setup=[RelabelFixture] begin
    md = series()
    out = PVMeteo.relabel(md, PVMeteo.RightLabeled())
    @test out.time == md.time .+ Hour(1)
    @test out.meta.label === PVMeteo.RightLabeled()
end

@testitem "right to left shifts back" tags=[:unit, :fast] setup=[RelabelFixture] begin
    md = series(; label = PVMeteo.RightLabeled())
    out = PVMeteo.relabel(md, PVMeteo.LeftLabeled())
    @test out.time == md.time .- Hour(1)
end

@testitem "left to centre shifts by half" tags=[:unit, :fast] setup=[RelabelFixture] begin
    md = series()
    out = PVMeteo.relabel(md, PVMeteo.CenterLabeled())
    @test out.time == md.time .+ Minute(30)
end

@testitem "relabelling is an involution" tags=[:unit, :fast] setup=[RelabelFixture] begin
    for from in LABELS, to in LABELS
        md = series(; label = from)
        back = PVMeteo.relabel(PVMeteo.relabel(md, to), from)
        @test back.time == md.time
        @test back.meta.label === from
    end
end

@testitem "relabel leaves the data alone" tags=[:unit, :fast] setup=[RelabelFixture] begin
    md = series()
    out = PVMeteo.relabel(md, PVMeteo.RightLabeled())
    @test out.data.ghi === md.data.ghi
    @test out.meta.interval === md.meta.interval
    @test out.meta.content_hash == md.meta.content_hash
end

@testitem "relabel records its lineage" tags=[:unit, :fast] setup=[RelabelFixture] begin
    md = series()
    @test PVMeteo.relabel(md, PVMeteo.RightLabeled()).meta.lineage == [:relabel]
    same = PVMeteo.relabel(md, PVMeteo.LeftLabeled())
    @test same.time == md.time
    @test same.meta.lineage == [:relabel]
    @test isempty(md.meta.lineage)
end

@testitem "a quarter hour centres cleanly" tags=[:unit, :fast] setup=[RelabelFixture] begin
    md = series(; interval = Minute(15))
    out = PVMeteo.relabel(md, PVMeteo.CenterLabeled())
    @test out.time == md.time .+ Minute(7) .+ Second(30)
end

@testitem "an odd interval cannot centre" tags=[:unit, :fast] setup=[RelabelFixture] begin
    md = series(; interval = Millisecond(3))
    @test_throws ArgumentError PVMeteo.relabel(md, PVMeteo.CenterLabeled())
    @test PVMeteo.relabel(md, PVMeteo.RightLabeled()).time == md.time .+ Millisecond(3)
end

@testitem "relabel works on a real file" tags=[:unit, :fast] setup=[RelabelFixture] begin
    md = PVMeteo.read_epw(fixture("minimal.epw"))
    out = PVMeteo.relabel(md, PVMeteo.LeftLabeled())
    @test out.time == md.time .- Hour(1)
    @test out.meta.label === PVMeteo.LeftLabeled()
    @test out.meta.lineage == [:relabel]
end
