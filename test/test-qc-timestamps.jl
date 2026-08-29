@testsnippet TSFixture begin
    using Dates
    fixture(name) = joinpath(@__DIR__, "fixtures", name)

    function series(times; interval = Hour(1))
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
        return PVMeteo.MeteoData(times, (; ghi = zeros(length(times))), meta)
    end

    hourly(n) = collect(DateTime(2026, 1, 1):Hour(1):(DateTime(2026, 1, 1)+Hour(n-1)))
    checks(flags) = sort(unique(f.check for f in flags))
    only_check(flags, name) = only(filter(f -> f.check === name, flags))
end

@testitem "a clean file raises nothing" tags=[:unit, :fast] setup=[TSFixture] begin
    for name in ("minimal.epw", "subhourly.epw", "dst_spring.epw", "dst_autumn.epw")
        md = PVMeteo.read_epw(fixture(name))
        @test isempty(PVMeteo.check_timestamps(md))
    end
end

@testitem "duplicates are flagged" tags=[:unit, :fast] setup=[TSFixture] begin
    md = PVMeteo.read_epw(fixture("dst_duplicate.epw"))
    flags = PVMeteo.check_timestamps(md)
    dup = only_check(flags, :duplicate_ts)
    @test dup.severity == :error
    @test dup.column === nothing
    @test length(dup.indices) == 1
    @test md.time[dup.indices[1]] == md.time[dup.indices[1]-1]
end

@testitem "gaps are flagged with their span" tags=[:unit, :fast] setup=[TSFixture] begin
    md = PVMeteo.read_epw(fixture("gap.epw"))
    gap = only_check(PVMeteo.check_timestamps(md), :gap)
    @test gap.severity == :warn
    @test gap.indices == [31]
    @test md.time[31] - md.time[30] == Hour(5)
    @test occursin("4", gap.detail)
end

@testitem "decreasing time is flagged" tags=[:unit, :fast] setup=[TSFixture] begin
    t = hourly(5)
    t[4] = DateTime(2026, 1, 1)
    flags = PVMeteo.check_timestamps(series(t))
    nm = only_check(flags, :non_monotonic)
    @test nm.severity == :error
    @test nm.indices == [4]
end

@testitem "spacing is compared to the meta" tags=[:unit, :fast] setup=[TSFixture] begin
    md = series(hourly(6); interval = Minute(15))
    sm = only_check(PVMeteo.check_timestamps(md), :spacing_mismatch)
    @test sm.severity == :warn
    @test occursin("15 minutes", sm.detail)
    @test occursin("1 hour", sm.detail)
end

@testitem "matching spacing raises nothing" tags=[:unit, :fast] setup=[TSFixture] begin
    @test isempty(PVMeteo.check_timestamps(series(hourly(6))))
end

@testitem "one record is not a gap" tags=[:unit, :fast] setup=[TSFixture] begin
    @test isempty(PVMeteo.check_timestamps(series(hourly(1))))
end

@testitem "a duplicate is not also a gap" tags=[:unit, :fast] setup=[TSFixture] begin
    t = hourly(4)
    insert!(t, 3, t[2])
    @test checks(PVMeteo.check_timestamps(series(t))) == [:duplicate_ts]
end

@testitem "gap details read naturally" tags=[:unit, :fast] setup=[TSFixture] begin
    t = hourly(10)
    deleteat!(t, 4)
    @test occursin(
        "1 record missing",
        only_check(PVMeteo.check_timestamps(series(t)), :gap).detail,
    )

    u = hourly(12)
    deleteat!(u, [4, 8, 9])
    d = only_check(PVMeteo.check_timestamps(series(u)), :gap).detail
    @test occursin("3 records missing across 2 gaps", d)
end
