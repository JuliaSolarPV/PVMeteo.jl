"""
    validate(md::MeteoData; cosz = nothing, limits = BSRN(), closure_tol = 0.08,
             minimum_run = 6) -> QCReport

Run every quality control check over `md` and collect the findings.

`md` is never modified. Use [`apply`](@ref) to act on the report.

The timestamp and constant-run checks always run. The BSRN limits and the closure
test need the cosine of the solar zenith angle at each record, so they run only
when `cosz` is given. Without it the report carries an `:info` flag
`:skipped_needs_cosz`, so a clean report is never mistaken for a complete one.
"""
function validate(
    md::MeteoData;
    cosz = nothing,
    limits::BSRN = BSRN(),
    closure_tol::Real = 0.08,
    minimum_run::Integer = 6,
)
    flags = QCFlag[]
    append!(flags, check_timestamps(md))
    append!(flags, check_constant_runs(md; minimum_run = minimum_run))
    if cosz === nothing
        push!(
            flags,
            QCFlag(
                :skipped_needs_cosz,
                Int[],
                :info,
                "the limit and closure checks need cos(zenith) at each record. " *
                "Pass cosz to run them.",
            ),
        )
    else
        append!(flags, check_limits(md, cosz, limits))
        append!(flags, check_closure(md, cosz; tol = closure_tol))
    end
    return QCReport(flags, length(md.time))
end
