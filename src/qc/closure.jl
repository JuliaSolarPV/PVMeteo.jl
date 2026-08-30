"""
Below this GHI the closure ratio is dominated by sensor offsets rather than by the
components, so the check has nothing to say.
"""
const CLOSURE_MIN_GHI = 50.0

"""
Cosine of the zenith angles that bound the three closure regimes. Below 75 degrees
the ratio is tight, between 75 and 93 degrees the long air mass loosens it, and
past 93 degrees the sun is down.
"""
const COS_75, COS_93, COS_95 = cosd(75.0), cosd(93.0), cosd(95.0)

"""Tolerance between 75 and 93 degrees, where the components disagree more."""
const CLOSURE_HIGH_ZENITH_TOL = 0.15

"""A GHI above this with the sun well below the horizon is a fault."""
const NIGHT_MAX_GHI = 5.0

"""
    check_closure(md::MeteoData, cosz; tol = 0.08) -> Vector{QCFlag}

Test the three irradiance components against `ghi == dhi + dni * cos(zenith)`.

`cosz` is the cosine of the solar zenith angle at each record, supplied by the
caller. A ratio further from one than `tol` is a `:closure` error below 75 degrees
zenith, and further than 0.15 between 75 and 93 degrees. Records with GHI at or
below 50 W/m^2, and records with the sun past 93 degrees, are skipped.

`:night_nonzero` is a warning for GHI above 5 W/m^2 with the sun past 95 degrees.

A source missing any of the three components yields a single `:info` flag naming
what is absent.
"""
function check_closure(md::MeteoData, cosz; tol::Real = 0.08)
    nrec = length(md.time)
    length(cosz) == nrec ||
        throw(DimensionMismatch("cosz has $(length(cosz)) values for $nrec records"))

    absent = filter(name -> !hascolumn(md, name), IRRADIANCE)
    isempty(absent) || return [
        QCFlag(
            :closure_unavailable,
            Int[],
            :info,
            "closure needs :ghi, :dni and :dhi. This source has no " *
            join((":$name" for name in absent), ", "),
        ),
    ]

    ghi_, dni_, dhi_ = md.data.ghi, md.data.dni, md.data.dhi
    inconsistent = Int[]
    lit_at_night = Int[]
    for i = 1:nrec
        mu = float(cosz[i])
        g = float(ghi_[i])
        (isfinite(mu) && isfinite(g)) || continue
        if mu < COS_95
            g > NIGHT_MAX_GHI && push!(lit_at_night, i)
            continue
        end
        (g > CLOSURE_MIN_GHI && mu > COS_93) || continue
        total = float(dhi_[i]) + float(dni_[i]) * max(mu, 0.0)
        total > 0 || continue
        limit = mu >= COS_75 ? float(tol) : CLOSURE_HIGH_ZENITH_TOL
        abs(g / total - 1) > limit && push!(inconsistent, i)
    end

    flags = QCFlag[]
    isempty(inconsistent) || push!(
        flags,
        QCFlag(
            :closure,
            inconsistent,
            :error,
            "ghi differs from dhi + dni * cos(zenith) by more than the tolerance",
            :ghi,
        ),
    )
    isempty(lit_at_night) || push!(
        flags,
        QCFlag(
            :night_nonzero,
            lit_at_night,
            :warn,
            "ghi is nonzero with the sun down",
            :ghi,
        ),
    )
    return flags
end
