"""
    IntervalLabel

Where a timestamp sits inside the interval it labels.

Irradiance is integrated over an interval and the sun moves within it, so reading
a left-labelled file as right-labelled shifts every record by one interval.
Encoding the convention in the type makes a mismatch a method error.
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

`interval` is a type parameter so the struct stays concrete. Timestamps in the accompanying data are always UTC.
`utc_offset` records the offset of the source so local time can be recovered at
the boundary.

Anything a parser could not map to a canonical column lands in `extra`. No
reader silently drops information.
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
    lineage::Vector{Symbol}
    station::Union{Nothing,String}
    extra::Dict{Symbol,Any}
end

function MeteoMeta(;
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
    lineage = Symbol[],
    station = nothing,
    extra = Dict{Symbol,Any}(),
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
        lineage,
        station,
        extra,
    )
end

"""
    MeteoData{T,N,L,P,C}

A meteorological time series and the metadata needed to interpret it.

`time` is always UTC. `data` is a `NamedTuple` of equal-length `Vector{T}`, which
keeps the container generic over `T`. `Float32`, `BigFloat`, dual numbers
and uncertainty types are all supported. Use the Tables.jl interface for interop
with tabular packages.

Construction validates only that every column matches `length(time)`. Timestamp
monotonicity, uniform spacing and agreement with `meta.interval` are *not*
enforced here: reading a file must never reject data, and a source with DST
artefacts has to be constructible for quality control to report on it. Use
[`validate`](@ref) for those checks.
"""
struct MeteoData{T,N,L<:IntervalLabel,P<:Period,C<:NamedTuple{N,<:Tuple{Vararg{Vector{T}}}}}
    time::Vector{DateTime}
    data::C
    meta::MeteoMeta{L,P}

    function MeteoData(
        time::Vector{DateTime},
        data::C,
        meta::MeteoMeta{L,P},
    ) where {T,N,L<:IntervalLabel,P<:Period,C<:NamedTuple{N,<:Tuple{Vararg{Vector{T}}}}}
        isempty(N) && throw(ArgumentError("MeteoData needs at least one data column"))
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

function Base.show(io::IO, ::MIME"text/plain", md::MeteoData{T,N}) where {T,N}
    n = length(md.time)
    print(io, "MeteoData{$T}: $n records")
    if n > 0
        print(io, ", ", first(md.time), " to ", last(md.time), " UTC")
    end
    println(io)
    println(io, "  source:   ", md.meta.source, " (", md.meta.origin, ")")
    println(io, "  interval: ", md.meta.interval, ", ", nameof(typeof(md.meta.label)))
    println(io, "  columns:  ", join(N, ", "))
    isempty(md.meta.lineage) || println(io, "  lineage:  ", join(md.meta.lineage, " -> "))
    return nothing
end

"""
The same span in the coarsest unit that divides it exactly. An interval derived
by division is a `Millisecond` even when it is a whole hour.
"""
function canonical_interval(p::Period)
    ms = Dates.toms(p)
    ms > 0 || throw(ArgumentError("interval must be positive, got $p"))
    ms % 3_600_000 == 0 && return Hour(ms ÷ 3_600_000)
    ms % 60_000 == 0 && return Minute(ms ÷ 60_000)
    ms % 1_000 == 0 && return Second(ms ÷ 1_000)
    return Millisecond(ms)
end
