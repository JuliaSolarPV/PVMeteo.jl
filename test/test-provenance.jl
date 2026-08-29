@testsnippet ProvFixture begin
    using Dates

    function meta_with(; lineage = Symbol[], extra = Dict{Symbol, Any}())
        return PVMeteo.MeteoMeta(;
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
            lineage = lineage,
            extra = extra,
        )
    end
end

@testitem "content_hash is stable for equal bytes" tags=[:unit, :fast] begin
    bytes = Vector{UInt8}("LOCATION,De Bilt,-,NLD")
    @test PVMeteo.content_hash(bytes) == PVMeteo.content_hash(copy(bytes))
end

@testitem "content_hash separates different bytes" tags=[:unit, :fast] begin
    a = Vector{UInt8}("LOCATION,De Bilt,-,NLD,52.10,5.18,1.0,2.0")
    b = copy(a)
    b[end] = UInt8('3')          # altitude 2.0 -> 2.3
    @test a != b
    @test PVMeteo.content_hash(a) != PVMeteo.content_hash(b)
end

@testitem "content_hash is pinned across versions" tags=[:unit, :fast] begin
    # Leading 8 bytes of sha256("PVMeteo"), little-endian. A change here means the
    # hash is no longer reproducible against previously cached data.
    @test PVMeteo.content_hash(Vector{UInt8}("PVMeteo")) === 0x0dc9b13eb399dcdd
end

@testitem "content_hash reads a file" tags=[:unit, :fast] begin
    path, io = mktemp()
    write(io, "PVMeteo")
    close(io)
    @test PVMeteo.content_hash(path) == PVMeteo.content_hash(Vector{UInt8}("PVMeteo"))
    rm(path)
end

@testitem "with_lineage appends without mutating" tags=[:unit, :fast] setup=[ProvFixture] begin
    original = meta_with()
    derived = PVMeteo.with_lineage(original, :relabel)
    @test derived.lineage == [:relabel]
    @test original.lineage == Symbol[]
    twice = PVMeteo.with_lineage(derived, :subset)
    @test twice.lineage == [:relabel, :subset]
    @test derived.lineage == [:relabel]
end

@testitem "with_lineage carries the rest across" tags=[:unit, :fast] setup=[ProvFixture] begin
    original = meta_with()
    derived = PVMeteo.with_lineage(original, :relabel)
    for f in (:latitude, :longitude, :altitude, :utc_offset, :label, :interval,
              :source, :origin, :retrieved, :content_hash, :station)
        @test getfield(derived, f) == getfield(original, f)
    end
end

@testitem "with_lineage copies extra" tags=[:unit, :fast] setup=[ProvFixture] begin
    original = meta_with(; extra = Dict{Symbol, Any}(:comments_1 => "hi"))
    derived = PVMeteo.with_lineage(original, :subset)
    @test derived.extra == original.extra
    derived.extra[:comments_1] = "changed"
    @test original.extra[:comments_1] == "hi"
end
