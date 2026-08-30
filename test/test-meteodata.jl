@testsnippet MetaFixture begin
    using Dates

    function make_meta(; label = PVMeteo.LeftLabeled(), interval = Hour(1), kwargs...)
        return PVMeteo.MeteoMeta(;
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
            kwargs...,
        )
    end

    hours(n) = collect(DateTime(2026, 1, 1):Hour(1):(DateTime(2026, 1, 1)+Hour(n-1)))
end

@testitem "MeteoData holds its columns" tags=[:unit, :fast] setup=[MetaFixture] begin
    t = hours(3)
    md = PVMeteo.MeteoData(t, (; ghi = [1.0, 2.0, 3.0]), make_meta())
    @test md.time == t
    @test md.data.ghi == [1.0, 2.0, 3.0]
    @test md.meta.source == :test
end

@testitem "MeteoData is generic in T" tags=[:unit, :fast] setup=[MetaFixture] begin
    md64 = PVMeteo.MeteoData(hours(2), (; ghi = [1.0, 2.0]), make_meta())
    md32 = PVMeteo.MeteoData(hours(2), (; ghi = Float32[1, 2]), make_meta())
    @test md64 isa PVMeteo.MeteoData{Float64}
    @test md32 isa PVMeteo.MeteoData{Float32}
end

@testitem "MeteoData rejects ragged columns" tags=[:unit, :fast] setup=[MetaFixture] begin
    err = try
        PVMeteo.MeteoData(hours(3), (; ghi = [1.0, 2.0]), make_meta())
        nothing
    catch e
        e
    end
    @test err isa DimensionMismatch
    @test occursin("ghi", err.msg)
    @test occursin("2", err.msg)
    @test occursin("3", err.msg)
end

@testitem "MeteoData rejects no columns" tags=[:unit, :fast] setup=[MetaFixture] begin
    @test_throws ArgumentError PVMeteo.MeteoData(hours(3), NamedTuple(), make_meta())
end

@testitem "MeteoData allows unsorted time" tags=[:unit, :fast] setup=[MetaFixture] begin
    # Parsing must never reject data. Timestamp regularity is a QC concern.
    t = [DateTime(2026, 1, 1, 2), DateTime(2026, 1, 1, 1), DateTime(2026, 1, 1, 1)]
    md = PVMeteo.MeteoData(t, (; ghi = [1.0, 2.0, 3.0]), make_meta())
    @test md.time == t
end

@testitem "MeteoData show is a summary" tags=[:unit, :fast] setup=[MetaFixture] begin
    md = PVMeteo.MeteoData(
        hours(3),
        (; ghi = [1.0, 2.0, 3.0], temp_air = [5.0, 6.0, 7.0]),
        make_meta(),
    )
    s = sprint(show, MIME("text/plain"), md)
    @test occursin("MeteoData", s)
    @test occursin("3", s)
    @test occursin("ghi", s)
    @test occursin("temp_air", s)
    @test occursin("test", s)
    @test !occursin("[1.0, 2.0, 3.0]", s)  # no data dump
    @test !occursin("out of order", s)
end

@testitem "show spans an unsorted axis" tags=[:unit, :fast] setup=[MetaFixture] begin
    using Dates
    shuffled = [DateTime(2026, 1, 1, 2), DateTime(2026, 1, 1), DateTime(2026, 1, 1, 1)]
    md = PVMeteo.MeteoData(shuffled, (; ghi = [1.0, 2.0, 3.0]), make_meta())
    s = sprint(show, MIME("text/plain"), md)
    @test occursin("2026-01-01T00:00:00 to 2026-01-01T02:00:00", s)
    @test occursin("out of order", s)
end
