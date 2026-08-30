@testsnippet TableFixture begin
    using Dates
    using Tables

    function tabular()
        meta = PVMeteo.MeteoMeta(;
            latitude = 52.0,
            longitude = 4.9,
            altitude = 10.0,
            utc_offset = Minute(0),
            label = PVMeteo.LeftLabeled(),
            interval = Hour(1),
            source = :test,
            origin = "memory",
            retrieved = DateTime(2026, 1, 1),
            content_hash = UInt64(0),
        )
        t = [DateTime(2026, 1, 1), DateTime(2026, 1, 1, 1), DateTime(2026, 1, 1, 2)]
        nt = (; ghi = [1.0, 2.0, 3.0], temp_air = [4.0, 5.0, 6.0])
        return PVMeteo.MeteoData(t, nt, meta)
    end
end

@testitem "MeteoData is a table" tags=[:unit, :fast] setup=[TableFixture] begin
    @test Tables.istable(PVMeteo.MeteoData)
    @test Tables.columnaccess(PVMeteo.MeteoData)
end

@testitem "columntable round-trips values" tags=[:unit, :fast] setup=[TableFixture] begin
    md = tabular()
    ct = Tables.columntable(md)
    @test keys(ct) == (:time, :ghi, :temp_air)
    @test ct.time == md.time
    @test ct.ghi == [1.0, 2.0, 3.0]
    @test ct.temp_air == [4.0, 5.0, 6.0]
end

@testitem "schema puts time first" tags=[:unit, :fast] setup=[TableFixture] begin
    s = Tables.schema(tabular())
    @test s.names == (:time, :ghi, :temp_air)
    @test s.types == (DateTime, Float64, Float64)
end

@testitem "schema follows the element type" tags=[:unit, :fast] setup=[TableFixture] begin
    md = tabular()
    md32 = PVMeteo.MeteoData(md.time, (; ghi = Float32.(md.data.ghi)), md.meta)
    @test Tables.schema(md32).types == (DateTime, Float32)
end

@testitem "rowtable has one row per record" tags=[:unit, :fast] setup=[TableFixture] begin
    md = tabular()
    rows = Tables.rowtable(md)
    @test length(rows) == length(md.time)
    @test first(rows).ghi == 1.0
    @test first(rows).time == md.time[1]
end

@testitem "columnnames works on the table" tags=[:unit, :fast] setup=[TableFixture] begin
    md = tabular()
    @test Tables.columnnames(md) == (:time, :ghi, :temp_air)
    @test Tables.columnnames(md) == Tables.columnnames(Tables.columns(md))
    @test Tables.columnnames(md) == Tables.schema(md).names
end
