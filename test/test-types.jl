@testitem "MeteoMeta is concrete and typed by label" tags=[:unit, :fast] begin
    using Dates
    m = PVMeteo.MeteoMeta(;
        latitude = 52.0,
        longitude = 4.9,
        altitude = 10.0,
        utc_offset = Minute(60),
        label = PVMeteo.RightLabeled(),
        interval = Hour(1),
        source = :epw,
        origin = "x.epw",
        retrieved = DateTime(2026, 1, 1),
        content_hash = UInt64(7),
    )
    @test isconcretetype(typeof(m))
    @test m isa PVMeteo.MeteoMeta{PVMeteo.RightLabeled,Hour}
    @test m.history == Symbol[]
    @test m.station === nothing
    @test isempty(m.extra)
end

@testitem "MeteoMeta rejects out-of-range coordinates" tags=[:unit, :fast] begin
    using Dates
    base = (;
        altitude = 10.0,
        utc_offset = Minute(0),
        label = PVMeteo.LeftLabeled(),
        interval = Hour(1),
        source = :csv,
        origin = "x.csv",
        retrieved = DateTime(2026, 1, 1),
        content_hash = UInt64(0),
    )
    @test_throws ArgumentError PVMeteo.MeteoMeta(;
        latitude = 91.0,
        longitude = 0.0,
        base...,
    )
    @test_throws ArgumentError PVMeteo.MeteoMeta(;
        latitude = 0.0,
        longitude = -181.0,
        base...,
    )
end

@testitem "The interval labels are distinct singletons" tags=[:unit, :fast] begin
    labels = (PVMeteo.LeftLabeled(), PVMeteo.RightLabeled(), PVMeteo.CenterLabeled())
    @test all(l -> l isa PVMeteo.IntervalLabel, labels)
    @test length(unique(typeof.(labels))) == 3
    @test all(l -> isbitstype(typeof(l)), labels)
end

@testitem "canonical_interval picks the coarsest unit" tags=[:unit, :fast] begin
    using Dates
    @test PVMeteo.canonical_interval(Millisecond(3_600_000)) === Hour(1)
    @test PVMeteo.canonical_interval(Millisecond(900_000)) === Minute(15)
    @test PVMeteo.canonical_interval(Millisecond(30_000)) === Second(30)
    @test PVMeteo.canonical_interval(Millisecond(1_500)) === Millisecond(1500)
    @test PVMeteo.canonical_interval(Hour(2)) === Hour(2)
    @test PVMeteo.canonical_interval(Minute(90)) === Minute(90)
    @test_throws ArgumentError PVMeteo.canonical_interval(Second(0))
end
