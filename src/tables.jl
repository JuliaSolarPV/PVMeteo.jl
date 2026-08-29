Tables.istable(::Type{<:MeteoData}) = true
Tables.columnaccess(::Type{<:MeteoData}) = true
Tables.columns(md::MeteoData) = merge((; time = md.time), md.data)

function Tables.schema(::MeteoData{T,N}) where {T,N}
    return Tables.Schema((:time, N...), (DateTime, ntuple(_ -> T, length(N))...))
end
