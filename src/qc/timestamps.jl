"""
    check_timestamps(md::MeteoData) -> Vector{QCFlag}

Inspect the time axis of `md`.

Reports four things. `:duplicate_ts` marks a record whose timestamp repeats its
predecessor. `:non_monotonic` marks a record that moves backwards. `:gap` marks the
record after a hole, with the missing span in its detail. `:spacing_mismatch` fires
once when the most common spacing disagrees with `meta.interval`.

All four describe the time axis, so none of them names a column.
"""
function check_timestamps(md::MeteoData)
    flags = QCFlag[]
    t = md.time
    length(t) < 2 && return flags

    steps = diff(t)
    interval = Millisecond(md.meta.interval)

    duplicates = findall(==(Millisecond(0)), steps) .+ 1
    isempty(duplicates) || push!(
        flags,
        QCFlag(
            :duplicate_ts,
            duplicates,
            :error,
            "timestamp repeats the previous record",
        ),
    )

    backwards = findall(<(Millisecond(0)), steps) .+ 1
    isempty(backwards) || push!(
        flags,
        QCFlag(:non_monotonic, backwards, :error, "timestamp moves backwards"),
    )

    modal = modal_step(steps)
    if modal !== nothing && modal != interval
        push!(
            flags,
            QCFlag(
                :spacing_mismatch,
                Int[],
                :warn,
                "records are spaced $(canonical_interval(modal)) but meta.interval " *
                "says $(md.meta.interval)",
            ),
        )
    end

    expected = modal === nothing ? interval : modal
    if expected > Millisecond(0)
        holes = Int[]
        missing_counts = Int[]
        for (i, step) in enumerate(steps)
            if step > expected
                push!(holes, i + 1)
                push!(missing_counts, Int(Dates.value(step) ÷ Dates.value(expected)) - 1)
            end
        end
        isempty(holes) || push!(
            flags,
            QCFlag(
                :gap,
                holes,
                :warn,
                gap_detail(sum(missing_counts), length(holes)),
            ),
        )
    end

    return flags
end

function gap_detail(missing_records, n_gaps)
    records = missing_records == 1 ? "1 record" : "$missing_records records"
    n_gaps == 1 && return "$records missing"
    return "$records missing across $n_gaps gaps"
end

"""The most common positive spacing, or `nothing` when there is none."""
function modal_step(steps)
    counts = Dict{Millisecond, Int}()
    for s in steps
        s > Millisecond(0) || continue
        ms = Millisecond(s)
        counts[ms] = get(counts, ms, 0) + 1
    end
    isempty(counts) && return nothing
    return argmax(counts)
end
