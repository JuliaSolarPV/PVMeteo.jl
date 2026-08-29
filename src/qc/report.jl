const SEVERITIES = (:info, :warn, :error)

"""
    QCFlag(check, indices, severity, detail, column = nothing)

One quality control finding.

`indices` are positions in the series. `column` names the affected column, or is
`nothing` for a finding about the time axis itself, such as a duplicate timestamp.
Severity is one of `:info`, `:warn` or `:error`.
"""
struct QCFlag
    check::Symbol
    indices::Vector{Int}
    severity::Symbol
    detail::String
    column::Union{Nothing,Symbol}

    function QCFlag(check, indices, severity, detail, column = nothing)
        severity in SEVERITIES ||
            throw(ArgumentError("severity :$severity must be one of $(SEVERITIES)"))
        return new(
            Symbol(check),
            collect(Int, indices),
            Symbol(severity),
            String(detail),
            column,
        )
    end
end

"""
    QCReport(flags, n_records)

The findings of a [`validate`](@ref) run over `n_records` records.
"""
struct QCReport
    flags::Vector{QCFlag}
    n_records::Int
end

severity_rank(s::Symbol) = findfirst(==(s), SEVERITIES)

function Base.show(io::IO, ::MIME"text/plain", r::QCReport)
    print(io, "QCReport: ", r.n_records, " records")
    if isempty(r.flags)
        println(io, ", no flags")
        return nothing
    end
    println(io, ", ", length(r.flags), " flags")
    for f in sort(r.flags; by = f -> (-severity_rank(f.severity), f.check))
        where_ = f.column === nothing ? "" : " on :$(f.column)"
        println(
            io,
            "  ",
            rpad(string(f.severity), 6),
            f.check,
            where_,
            ": ",
            length(f.indices),
            length(f.indices) == 1 ? " record. " : " records. ",
            f.detail,
        )
    end
    return nothing
end

const APPLY_POLICIES = (:mask, :interpolate, :drop)

"""
    apply(md::MeteoData, report::QCReport; policy = :mask, severity = :error)

A copy of `md` with the findings in `report` acted on.

`:mask` writes `NaN` at the flagged indices of the column each flag names, for
flags at or above `severity`. Flags that name no column describe the time axis and
are left alone, because a duplicate timestamp says nothing about the values
recorded at it.

`:interpolate` and `:drop` need the resampling machinery and are not available yet.
"""
function apply(
    md::MeteoData{T},
    report::QCReport;
    policy::Symbol = :mask,
    severity::Symbol = :error,
) where {T}
    policy in APPLY_POLICIES ||
        throw(ArgumentError("unknown policy :$policy, expected one of $(APPLY_POLICIES)"))
    policy === :mask || throw(
        ArgumentError(
            "policy :$policy is not available yet and arrives with resampling. " *
            "Use :mask.",
        ),
    )
    severity in SEVERITIES ||
        throw(ArgumentError("severity :$severity must be one of $(SEVERITIES)"))
    T <: AbstractFloat || throw(
        ArgumentError(
            "policy :mask writes NaN, which $T cannot hold. " *
            "Read the source with a floating point element type.",
        ),
    )

    floor_ = severity_rank(severity)
    columns_ = Dict(name => copy(v) for (name, v) in pairs(md.data))
    for f in report.flags
        f.column === nothing && continue
        severity_rank(f.severity) >= floor_ || continue
        haskey(columns_, f.column) || continue
        column = columns_[f.column]
        for i in f.indices
            checkbounds(Bool, column, i) || throw(
                ArgumentError(
                    "flag :$(f.check) points at record $i, outside 1:$(length(column))",
                ),
            )
            column[i] = T(NaN)
        end
    end

    data = NamedTuple{keys(md.data)}(Tuple(columns_[k] for k in keys(md.data)))
    return MeteoData(copy(md.time), data, with_lineage(md.meta, :qc_mask))
end
