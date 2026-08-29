# Tables.jl interop. MeteoData stores a NamedTuple of vectors rather than a
# DataFrame so the container stays generic over its element type. This interface
# is what makes `DataFrame(md)` and friends work anyway, for anyone who wants it.

Tables.istable(::Type{<:MeteoData}) = true
Tables.columnaccess(::Type{<:MeteoData}) = true
Tables.columns(md::MeteoData) = merge((; time = md.time), md.data)

function Tables.schema(::MeteoData{T,N}) where {T,N}
    return Tables.Schema((:time, N...), (DateTime, ntuple(_ -> T, length(N))...))
end
