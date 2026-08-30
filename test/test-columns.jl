@testsnippet ColumnFixture begin
    using Dates

    function tiny(nt)
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
        t = [DateTime(2026, 1, 1), DateTime(2026, 1, 1, 1)]
        return PVMeteo.MeteoData(t, nt, meta)
    end
end

@testitem "CANONICAL names the ten SI columns" tags=[:unit, :fast] begin
    @test PVMeteo.CANONICAL == (
        :ghi,
        :dni,
        :dhi,
        :temp_air,
        :wind_speed,
        :wind_direction,
        :pressure,
        :relative_humidity,
        :albedo,
        :precipitable_water,
    )
end

@testitem "datacolumns reports names in order" tags=[:unit, :fast] setup=[ColumnFixture] begin
    md = tiny((; ghi = [1.0, 2.0], temp_air = [3.0, 4.0]))
    @test PVMeteo.datacolumns(md) === (:ghi, :temp_air)
end

@testitem "hascolumn answers both ways" tags=[:unit, :fast] setup=[ColumnFixture] begin
    md = tiny((; ghi = [1.0, 2.0]))
    @test PVMeteo.hascolumn(md, :ghi)
    @test !PVMeteo.hascolumn(md, :dni)
end

@testitem "accessors return aliasing views" tags=[:unit, :fast] setup=[ColumnFixture] begin
    md = tiny((; ghi = [1.0, 2.0]))
    v = PVMeteo.ghi(md)
    @test v == [1.0, 2.0]
    v[1] = 99.0
    @test md.data.ghi[1] == 99.0
end

@testitem "a missing accessor names others" tags=[:unit, :fast] setup=[ColumnFixture] begin
    md = tiny((; ghi = [1.0, 2.0], temp_air = [3.0, 4.0]))
    err = try
        PVMeteo.dni(md)
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("dni", err.msg)
    @test occursin("ghi", err.msg)
    @test occursin("temp_air", err.msg)
end

@testitem "every canonical name accesses" tags=[:unit, :fast] setup=[ColumnFixture] begin
    for name in PVMeteo.CANONICAL
        md = tiny(NamedTuple{(name,)}(([1.0, 2.0],)))
        @test getfield(PVMeteo, name)(md) == [1.0, 2.0]
    end
end
