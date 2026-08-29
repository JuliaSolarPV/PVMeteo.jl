"""
Hash of the raw bytes a `MeteoData` was parsed from. Uses SHA-256 rather than
`Base.hash`, which is not stable across Julia versions.
"""
content_hash(bytes::AbstractVector{UInt8}) =
    first(reinterpret(UInt64, SHA.sha256(collect(bytes))))
content_hash(path::AbstractString) = content_hash(read(path))

"""
A copy of `meta` with `op` appended to its lineage. `extra` is copied rather than
shared, so a write through one object cannot alter another derived from it.
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
