"""
    content_hash(bytes::AbstractVector{UInt8}) -> UInt64
    content_hash(path::AbstractString) -> UInt64

A hash of the raw bytes a `MeteoData` was parsed from.

Together with `MeteoMeta.lineage` this is what makes "spec + data = reproducible
result" true: the hash pins the source, the lineage records everything done to it
since. `Base.hash` is not guaranteed stable across Julia versions, so this takes
the leading eight bytes of a SHA-256 digest instead, so the same file gives the
same value next year and on someone else's machine.
"""
content_hash(bytes::AbstractVector{UInt8}) =
    first(reinterpret(UInt64, SHA.sha256(collect(bytes))))
content_hash(path::AbstractString) = content_hash(read(path))

"""
    with_lineage(meta::MeteoMeta, op::Symbol) -> MeteoMeta

A copy of `meta` with `op` appended to its lineage.

Every transform returns a new object and records itself here, so a `MeteoData`
carries the full history of what was done to it after parsing. `extra` is copied
rather than shared: it is a mutable `Dict`, and aliasing it would let a write
through one object silently alter another derived from the same source.
"""
function with_lineage(meta::MeteoMeta, op::Symbol)
    return MeteoMeta(;
        latitude = meta.latitude,
        longitude = meta.longitude,
        altitude = meta.altitude,
        utc_offset = meta.utc_offset,
        label = meta.label,
        interval = meta.interval,
        source = meta.source,
        origin = meta.origin,
        retrieved = meta.retrieved,
        content_hash = meta.content_hash,
        lineage = vcat(meta.lineage, op),
        station = meta.station,
        extra = copy(meta.extra),
    )
end
