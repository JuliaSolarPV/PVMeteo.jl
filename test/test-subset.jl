@testsnippet SubsetFixture begin
    using Dates
    fixture(name) = joinpath(@__DIR__, "fixtures", name)

    function series(; n = 6, start = DateTime(2020, 6, 20), interval = Hour(1))
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
            content_hash = UInt64(42),
        )
        t = collect(start:interval:(start+interval*(n-1)))
        return PVMeteo.MeteoData(t, (; ghi = collect(1.0:n)), meta)
    end
end

@testitem "subset is half open" tags=[:unit, :fast] setup=[SubsetFixture] begin
    md = series()
    out = PVMeteo.subset(md, DateTime(2020, 6, 20, 1), DateTime(2020, 6, 20, 4))
    @test out.time == md.time[2:4]
    @test out.data.ghi == [2.0, 3.0, 4.0]
end

@testitem "subset covers the whole span" tags=[:unit, :fast] setup=[SubsetFixture] begin
    md = series()
    out = PVMeteo.subset(md, DateTime(2020, 6, 19), DateTime(2020, 6, 21))
    @test out.time == md.time
    @test out.data.ghi == md.data.ghi
end

@testitem "subset copies the columns" tags=[:unit, :fast] setup=[SubsetFixture] begin
    md = series()
    out = PVMeteo.subset(md, DateTime(2020, 6, 20), DateTime(2020, 6, 20, 3))
    out.data.ghi[1] = -1.0
    out.time[1] = DateTime(1999)
    @test md.data.ghi[1] == 1.0
    @test md.time[1] == DateTime(2020, 6, 20)
end

@testitem "subset records its history" tags=[:unit, :fast] setup=[SubsetFixture] begin
    md = series()
    out = PVMeteo.subset(md, DateTime(2020, 6, 20), DateTime(2020, 6, 20, 3))
    @test out.meta.history == [:subset]
    @test out.meta.content_hash == md.meta.content_hash
    @test isempty(md.meta.history)
end

@testitem "an empty range throws" tags=[:unit, :fast] setup=[SubsetFixture] begin
    md = series()
    @test_throws ArgumentError PVMeteo.subset(md, DateTime(2021), DateTime(2022))
    @test_throws ArgumentError PVMeteo.subset(
        md,
        DateTime(2020, 6, 20, 1, 1),
        DateTime(2020, 6, 20, 1, 59),
    )
end

@testitem "a reversed range throws" tags=[:unit, :fast] setup=[SubsetFixture] begin
    md = series()
    t = DateTime(2020, 6, 20, 2)
    @test_throws ArgumentError PVMeteo.subset(md, t, t - Hour(1))
    @test_throws ArgumentError PVMeteo.subset(md, t, t)
end

@testitem "subset composes with relabel" tags=[:unit, :fast] setup=[SubsetFixture] begin
    md = PVMeteo.read_epw(fixture("minimal.epw"))
    out = PVMeteo.subset(
        PVMeteo.relabel(md, PVMeteo.LeftLabeled()),
        DateTime(2020, 6, 20),
        DateTime(2020, 6, 21),
    )
    @test out.meta.history == [:relabel, :subset]
    @test length(out.time) == 24
    @test out.meta.label === PVMeteo.LeftLabeled()
end
