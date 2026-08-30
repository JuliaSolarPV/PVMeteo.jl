"""
Hash of the raw bytes a `MeteoData` was parsed from. Uses SHA-256, which is stable
across Julia versions.
"""
content_hash(bytes::Vector{UInt8}) = first(reinterpret(UInt64, SHA.sha256(bytes)))
content_hash(bytes::AbstractVector{UInt8}) = content_hash(Vector{UInt8}(bytes))
content_hash(path::AbstractString) = content_hash(read(path))

"""
A copy of `meta` with `op` appended to `meta.history`, optionally under a new
interval label. `extra` is copied, so each `meta` owns its own.
"""
function with_history(meta::MeteoMeta, op::Symbol; label::IntervalLabel = meta.label)
    return MeteoMeta(;
        latitude = meta.latitude,
        longitude = meta.longitude,
        altitude = meta.altitude,
        utc_offset = meta.utc_offset,
        label = label,
        interval = meta.interval,
        source = meta.source,
        origin = meta.origin,
        retrieved = meta.retrieved,
        content_hash = meta.content_hash,
        history = vcat(meta.history, op),
        station = meta.station,
        extra = copy(meta.extra),
    )
end
