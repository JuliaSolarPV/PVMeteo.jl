@testsnippet QCFixture begin
    using Dates

    function sample(; T = Float64)
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
        t = collect(DateTime(2026, 1, 1):Hour(1):DateTime(2026, 1, 1, 4))
        nt = (; ghi = T[1, 2, 3, 4, 5], temp_air = T[10, 11, 12, 13, 14])
        return PVMeteo.MeteoData(t, nt, meta)
    end

    flag(check, idx, sev, col = nothing) = PVMeteo.QCFlag(check, idx, sev, "detail", col)
end

@testitem "QCFlag checks its severity" tags=[:unit, :fast] setup=[QCFixture] begin
    @test flag(:closure, [1], :error).severity == :error
    @test_throws ArgumentError flag(:closure, [1], :critical)
end

@testitem "QCFlag may name a column" tags=[:unit, :fast] setup=[QCFixture] begin
    @test flag(:duplicate_ts, [2], :error).column === nothing
    @test flag(:physical_limit, [2], :error, :ghi).column === :ghi
end

@testitem "an empty report says so" tags=[:unit, :fast] begin
    s = sprint(show, MIME("text/plain"), PVMeteo.QCReport(PVMeteo.QCFlag[], 24))
    @test occursin("24", s)
    @test occursin("no flags", lowercase(s))
end

@testitem "a report lists each check" tags=[:unit, :fast] setup=[QCFixture] begin
    r = PVMeteo.QCReport(
        [flag(:closure, [1, 2, 3], :error, :ghi), flag(:gap, [5], :warn)],
        5,
    )
    s = sprint(show, MIME("text/plain"), r)
    @test occursin("closure", s)
    @test occursin("gap", s)
    @test occursin("3", s)
    @test occursin("error", s)
    @test occursin("warn", s)
end

@testitem "mask writes NaN in the flagged column" tags=[:unit, :fast] setup=[QCFixture] begin
    md = sample()
    r = PVMeteo.QCReport([flag(:physical_limit, [2, 4], :error, :ghi)], 5)
    out = PVMeteo.apply(md, r)
    @test isnan(out.data.ghi[2]) && isnan(out.data.ghi[4])
    @test out.data.ghi[[1, 3, 5]] == [1.0, 3.0, 5.0]
    @test out.data.temp_air == md.data.temp_air
end

@testitem "mask leaves the source alone" tags=[:unit, :fast] setup=[QCFixture] begin
    md = sample()
    r = PVMeteo.QCReport([flag(:physical_limit, [2], :error, :ghi)], 5)
    PVMeteo.apply(md, r)
    @test md.data.ghi == [1.0, 2.0, 3.0, 4.0, 5.0]
    @test isempty(md.meta.history)
end

@testitem "mask records itself in history" tags=[:unit, :fast] setup=[QCFixture] begin
    md = sample()
    r = PVMeteo.QCReport([flag(:physical_limit, [2], :error, :ghi)], 5)
    @test PVMeteo.apply(md, r).meta.history == [:qc_mask]
end

@testitem "mask skips flags with no column" tags=[:unit, :fast] setup=[QCFixture] begin
    # A duplicate timestamp says nothing about the values recorded at it.
    md = sample()
    r = PVMeteo.QCReport([flag(:duplicate_ts, [2], :error)], 5)
    out = PVMeteo.apply(md, r)
    @test out.data.ghi == md.data.ghi
    @test out.data.temp_air == md.data.temp_air
end

@testitem "mask honours the severity floor" tags=[:unit, :fast] setup=[QCFixture] begin
    md = sample()
    r = PVMeteo.QCReport(
        [
            flag(:a, [1], :info, :ghi),
            flag(:b, [2], :warn, :ghi),
            flag(:c, [3], :error, :ghi),
        ],
        5,
    )
    strict = PVMeteo.apply(md, r)
    @test !isnan(strict.data.ghi[1]) && !isnan(strict.data.ghi[2])
    @test isnan(strict.data.ghi[3])
    loose = PVMeteo.apply(md, r; severity = :info)
    @test all(isnan, loose.data.ghi[1:3])
end

@testitem "mask needs a float column" tags=[:unit, :fast] setup=[QCFixture] begin
    md = sample(; T = Int)
    r = PVMeteo.QCReport([flag(:physical_limit, [2], :error, :ghi)], 5)
    err = try
        PVMeteo.apply(md, r)
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("mask", err.msg)
    @test occursin("Int", err.msg)
end

@testitem "unknown policies are named" tags=[:unit, :fast] setup=[QCFixture] begin
    md = sample()
    r = PVMeteo.QCReport(PVMeteo.QCFlag[], 5)
    err = try
        PVMeteo.apply(md, r; policy = :obliterate)
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("obliterate", err.msg)
    @test occursin("mask", err.msg)
end

@testitem "unbuilt policies say so" tags=[:unit, :fast] setup=[QCFixture] begin
    md = sample()
    r = PVMeteo.QCReport(PVMeteo.QCFlag[], 5)
    for p in (:interpolate, :drop)
        err = try
            PVMeteo.apply(md, r; policy = p)
            nothing
        catch e
            e
        end
        @test err isa ArgumentError
        @test occursin(string(p), err.msg)
    end
end

@testitem "the report counts records readably" tags=[:unit, :fast] setup=[QCFixture] begin
    one = sprint(show, MIME("text/plain"), PVMeteo.QCReport([flag(:gap, [3], :warn)], 5))
    many =
        sprint(show, MIME("text/plain"), PVMeteo.QCReport([flag(:gap, [3, 4], :warn)], 5))
    @test occursin("1 record.", one)
    @test occursin("2 records.", many)
end
