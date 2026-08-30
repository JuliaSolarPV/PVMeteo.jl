"""
    IntervalLabel

Where a timestamp sits inside the interval it labels.

Irradiance is integrated over the interval and the sun moves within it, so the
convention is a type parameter of [`MeteoMeta`](@ref) and a mismatch is a method
error.
"""
abstract type IntervalLabel end

"""
    LeftLabeled()

The timestamp is the start of the interval: 10:00 covers 10:00 to 11:00.
"""
struct LeftLabeled <: IntervalLabel end

"""
    RightLabeled()

The timestamp is the end of the interval: 10:00 covers 09:00 to 10:00.

This is the EPW and TMY3 convention.
"""
struct RightLabeled <: IntervalLabel end

"""
    CenterLabeled()

The timestamp is the middle of the interval: 10:00 covers 09:30 to 10:30.
"""
struct CenterLabeled <: IntervalLabel end

"""
    MeteoMeta{L,P}

Everything needed to interpret a [`MeteoData`](@ref), and enough provenance to
reproduce it.

`label` and `interval` are type parameters, so the struct stays concrete.
`utc_offset` is the offset of the source, which recovers local time from the UTC
timestamps. `extra` holds every field a reader found without a canonical name.
"""
struct MeteoMeta{L<:IntervalLabel,P<:Period}
    latitude::Float64
    longitude::Float64
    altitude::Float64
    utc_offset::Minute
    label::L
    interval::P
    source::Symbol
    origin::String
    retrieved::DateTime
    content_hash::UInt64
    history::Vector{Symbol}
    station::Union{Nothing,String}
    extra::Dict{Symbol,Any}

    function MeteoMeta(
        latitude::Float64,
        longitude::Float64,
        altitude::Float64,
        utc_offset::Minute,
        label::L,
        interval::P,
        source::Symbol,
        origin::String,
        retrieved::DateTime,
        content_hash::UInt64,
        history::Vector{Symbol},
        station::Union{Nothing,String},
        extra::Dict{Symbol,Any},
    ) where {L<:IntervalLabel,P<:Period}
        return new{L,P}(
            latitude,
            longitude,
            altitude,
            utc_offset,
            label,
            interval,
            source,
            origin,
            retrieved,
            content_hash,
            history,
            station,
            extra,
        )
    end
end

function MeteoMeta(;
    latitude::Real,
    longitude::Real,
    altitude::Real,
    utc_offset::Period,
    label::IntervalLabel,
    interval::Period,
    source::Union{Symbol,AbstractString},
    origin::AbstractString,
    retrieved::DateTime,
    content_hash::Integer,
    history::Vector{Symbol} = Symbol[],
    station::Union{Nothing,AbstractString} = nothing,
    extra::AbstractDict{Symbol} = Dict{Symbol,Any}(),
)
    -90 <= latitude <= 90 || throw(ArgumentError("latitude $latitude is outside [-90, 90]"))
    -180 <= longitude <= 360 ||
        throw(ArgumentError("longitude $longitude is outside [-180, 360]"))
    return MeteoMeta(
        Float64(latitude),
        Float64(longitude),
        Float64(altitude),
        Minute(utc_offset),
        label,
        interval,
        Symbol(source),
        String(origin),
        retrieved,
        UInt64(content_hash),
        history,
        station === nothing ? nothing : String(station),
        convert(Dict{Symbol,Any}, extra),
    )
end

"""
    MeteoData{T,N,L,P,C}

A meteorological time series and the metadata needed to interpret it.

`time` is always UTC. `data` is a `NamedTuple` of equal-length `Vector{T}`, so `T`
is free: `Float32`, `BigFloat`, dual numbers and uncertainty types all work. The
Tables.jl interface gives interop with tabular packages.

Construction checks that every column matches `length(time)`. Use
[`validate`](@ref) for timestamp monotonicity, spacing and agreement with
`meta.interval`.
"""
struct MeteoData{T,N,L<:IntervalLabel,P<:Period,C<:NamedTuple{N,<:Tuple{Vararg{Vector{T}}}}}
    time::Vector{DateTime}
    data::C
    meta::MeteoMeta{L,P}

    function MeteoData{T,N,L,P,C}(
        time::Vector{DateTime},
        data::C,
        meta::MeteoMeta{L,P},
    ) where {T,N,L<:IntervalLabel,P<:Period,C<:NamedTuple{N,<:Tuple{Vararg{Vector{T}}}}}
        n = length(time)
        for (name, v) in pairs(data)
            length(v) == n || throw(
                DimensionMismatch(
                    "column :$name has $(length(v)) values but there are $n timestamps",
                ),
            )
        end
        return new{T,N,L,P,C}(time, data, meta)
    end
end

"""The element type shared by a NamedTuple of column vectors."""
column_eltype(::Type{<:NamedTuple{N,V}}) where {N,V} = eltype(eltype(V))

function MeteoData(
    time::Vector{DateTime},
    data::NamedTuple{N},
    meta::MeteoMeta{L,P},
) where {N,L<:IntervalLabel,P<:Period}
    isempty(N) && throw(ArgumentError("MeteoData needs at least one data column"))
    C = typeof(data)
    return MeteoData{column_eltype(C),N,L,P,C}(time, data, meta)
end

function Base.show(io::IO, ::MIME"text/plain", md::MeteoData{T,N}) where {T,N}
    n = length(md.time)
    print(io, "MeteoData{$T}: $n records")
    if n > 0
        earliest, latest = extrema(md.time)
        print(io, ", ", earliest, " to ", latest, " UTC")
    end
    println(io)
    println(io, "  source:   ", md.meta.source, " (", md.meta.origin, ")")
    println(io, "  interval: ", md.meta.interval, ", ", nameof(typeof(md.meta.label)))
    println(io, "  columns:  ", join(N, ", "))
    isempty(md.meta.history) || println(io, "  history:  ", join(md.meta.history, " -> "))
    issorted(md.time) ||
        println(io, "  warning:  timestamps are out of order, run validate")
    return nothing
end

"""
The same span in the coarsest unit that divides it exactly, so
`Millisecond(3600000)` becomes `Hour(1)`.
"""
function canonical_interval(p::Period)
    ms = Dates.toms(p)
    ms > 0 || throw(ArgumentError("interval must be positive, got $p"))
    ms % 3_600_000 == 0 && return Hour(ms ÷ 3_600_000)
    ms % 60_000 == 0 && return Minute(ms ÷ 60_000)
    ms % 1_000 == 0 && return Second(ms ÷ 1_000)
    return Millisecond(ms)
end
