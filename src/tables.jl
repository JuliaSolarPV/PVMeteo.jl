Tables.istable(::Type{<:MeteoData}) = true
Tables.columnaccess(::Type{<:MeteoData}) = true
Tables.columns(md::MeteoData) = merge((; time = md.time), md.data)

# Without this, the call falls through to Tables' universal fallback,
# `columnnames(x) = propertynames(x)`, which reports the struct fields
# `(:time, :data, :meta)`.
Tables.columnnames(::MeteoData{T,N}) where {T,N} = (:time, N...)

function Tables.schema(::MeteoData{T,N}) where {T,N}
    return Tables.Schema((:time, N...), (DateTime, ntuple(_ -> T, length(N))...))
end
