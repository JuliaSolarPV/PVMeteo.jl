"""
How far the timestamp sits from the start of the interval it labels. `relabel`
shifts by the difference of two of these.
"""
label_offset(::LeftLabeled, ::Period) = Millisecond(0)
label_offset(::CenterLabeled, interval::Period) = half_interval(interval)
label_offset(::RightLabeled, interval::Period) = Millisecond(interval)

function half_interval(interval::Period)
    ms = Dates.toms(interval)
    iseven(ms) || throw(
        ArgumentError(
            "interval $interval cannot be centre labelled, " *
            "it is an odd number of milliseconds",
        ),
    )
    return Millisecond(ms ÷ 2)
end

"""
    relabel(md::MeteoData, label::IntervalLabel) -> MeteoData

Move the timestamps to a different interval-labelling convention.

Each timestamp shifts by the offset between the two conventions. `meta.label`
becomes `label`, and the result records that `relabel` ran.

# Example

An hourly EPW file is `RightLabeled`, so 12:00 covers 11:00 to 12:00. The same
interval is 11:00 under `LeftLabeled`, carrying the same 739 W/m^2.

```julia
julia> md.meta.label, md.time[13], ghi(md)[13]
(RightLabeled(), DateTime("2020-06-20T12:00:00"), 739.0)

julia> left = relabel(md, LeftLabeled());

julia> left.meta.label, left.time[13], ghi(left)[13]
(LeftLabeled(), DateTime("2020-06-20T11:00:00"), 739.0)
```
"""
function relabel(md::MeteoData, label::IntervalLabel)
    interval = md.meta.interval
    shift = label_offset(label, interval) - label_offset(md.meta.label, interval)
    meta = with_history(md.meta, :relabel; label = label)
    return MeteoData(md.time .+ shift, md.data, meta)
end

"""
    subset(md::MeteoData, t0::DateTime, t1::DateTime) -> MeteoData

The records in the half-open interval `[t0, t1)`.

The columns are copied, so writes to the result do not reach the source.
`meta.content_hash` is carried over unchanged, because it identifies the bytes the
data was parsed from. The result records that `subset` ran, and that is what says
the data was narrowed.

A range that selects nothing throws rather than returning an empty `MeteoData`.
The search assumes the timestamps are sorted, so run [`validate`](@ref) first if
the source might be out of order.
"""
function subset(md::MeteoData, t0::DateTime, t1::DateTime)
    t1 > t0 || throw(ArgumentError("t1 $t1 must be after t0 $t0"))
    lo = searchsortedfirst(md.time, t0)
    hi = searchsortedfirst(md.time, t1) - 1
    lo <= hi || throw(
        ArgumentError(
            "[$t0, $t1) selects no records. " *
            "This series runs $(first(md.time)) to $(last(md.time)).",
        ),
    )
    keep = lo:hi
    return MeteoData(
        md.time[keep],
        map(v -> v[keep], md.data),
        with_history(md.meta, :subset),
    )
end
