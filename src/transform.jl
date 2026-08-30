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

Each column of the result is a fresh `Vector` holding the selected records.
`meta.content_hash` carries over, since it identifies the bytes the data was
parsed from, and the result records that `subset` ran.

A range that selects nothing throws. The search assumes sorted timestamps, so run
[`validate`](@ref) first when the source might be out of order.

# Example

```julia
julia> day = subset(md, DateTime(2020, 6, 21), DateTime(2020, 6, 22));

julia> length(day.time), day.time[1], day.time[end]
(24, DateTime("2020-06-21T00:00:00"), DateTime("2020-06-21T23:00:00"))

julia> day.data.ghi === md.data.ghi
false
```
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
