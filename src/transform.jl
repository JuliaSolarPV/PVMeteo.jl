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

Each timestamp shifts by the difference between the two conventions. The values are
untouched and the returned object shares them, because relabelling says where an
interval sits, not what was measured over it. Resampling to a different interval is
a separate operation.

`meta.label` becomes `label` and `:relabel` is appended to `meta.lineage`.
"""
function relabel(md::MeteoData, label::IntervalLabel)
    interval = md.meta.interval
    shift = label_offset(label, interval) - label_offset(md.meta.label, interval)
    meta = with_lineage(md.meta, :relabel; label = label)
    return MeteoData(md.time .+ shift, md.data, meta)
end
