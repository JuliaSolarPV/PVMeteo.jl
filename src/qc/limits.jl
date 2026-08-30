"""
    BSRN(; kwargs...)

Coefficients for the BSRN physically-possible and extremely-rare limits.

The bounds come from the Baseline Surface Radiation Network quality control
procedure and scale with `mu = cos(zenith)`, because the largest irradiance the
sky can deliver depends on how high the sun is. `Sa` below is the extraterrestrial
normal irradiance for the day.

| Quantity | Physically possible | Extremely rare |
|:---|:---|:---|
| GHI | `-4` to `Sa*1.5*mu^1.2 + 100` | `-2` to `Sa*1.2*mu^1.2 + 50` |
| DNI | `-4` to `Sa` | `-2` to `Sa*0.95*mu^0.2 + 10` |
| DHI | `-4` to `Sa*0.95*mu^1.2 + 50` | `-2` to `Sa*0.75*mu^1.2 + 30` |

The lower bounds are negative on purpose. A pyranometer radiating to a cold night
sky reads slightly below zero, and that thermal offset is normal behaviour.
"""
Base.@kwdef struct BSRN
    possible_floor::Float64 = -4.0
    rare_floor::Float64 = -2.0
    solar_constant::Float64 = 1367.0
end

"""
Extraterrestrial normal irradiance for a day of the year, in W/m^2. Varies by
about 3 percent over the year with the Earth to Sun distance.
"""
extraterrestrial_normal(doy::Integer, solar_constant = 1367.0) =
    solar_constant * (1 + 0.033 * cos(2pi * doy / 365))

ghi_possible(S, mu) = S * 1.5 * mu^1.2 + 100
ghi_rare(S, mu) = S * 1.2 * mu^1.2 + 50
dni_possible(S, mu) = S
dni_rare(S, mu) = S * 0.95 * mu^0.2 + 10
dhi_possible(S, mu) = S * 0.95 * mu^1.2 + 50
dhi_rare(S, mu) = S * 0.75 * mu^1.2 + 30

const LIMIT_CEILINGS = (
    (:ghi, ghi_possible, ghi_rare),
    (:dni, dni_possible, dni_rare),
    (:dhi, dhi_possible, dhi_rare),
)

"""
    check_limits(md::MeteoData, cosz, limits::BSRN = BSRN()) -> Vector{QCFlag}

Screen the irradiance columns against the BSRN bounds.

`cosz` is the cosine of the solar zenith angle at each record, supplied by the
caller. Columns the source does not carry are skipped.

A value outside the physically-possible band is an `:error`, since it cannot be
real and usually means a unit or scaling fault. A value only outside the
extremely-rare band is a `:warn`, since it can happen under cloud enhancement but
more often means drift or a soiled dome.
"""
function check_limits(md::MeteoData, cosz, limits::BSRN = BSRN())
    n = length(md.time)
    length(cosz) == n ||
        throw(DimensionMismatch("cosz has $(length(cosz)) values for $n records"))

    flags = QCFlag[]
    doys = Dates.dayofyear.(md.time)
    for (name, possible, rare) in LIMIT_CEILINGS
        hascolumn(md, name) || continue
        values = md.data[name]
        impossible = Int[]
        unusual = Int[]
        for i = 1:n
            S = extraterrestrial_normal(doys[i], limits.solar_constant)
            mu = max(float(cosz[i]), 0.0)
            v = float(values[i])
            isfinite(v) || continue
            if v < limits.possible_floor || v > possible(S, mu)
                push!(impossible, i)
            elseif v < limits.rare_floor || v > rare(S, mu)
                push!(unusual, i)
            end
        end
        isempty(impossible) || push!(
            flags,
            QCFlag(
                :physical_limit,
                impossible,
                :error,
                "$(name) outside the BSRN physically possible band",
                name,
            ),
        )
        isempty(unusual) || push!(
            flags,
            QCFlag(
                :extremely_rare,
                unusual,
                :warn,
                "$(name) outside the BSRN extremely rare band",
                name,
            ),
        )
    end
    return flags
end

"""
    check_constant_runs(md::MeteoData; minimum_run = 6) -> Vector{QCFlag}

Find runs of `minimum_run` or more identical consecutive values, which suggest a
stuck sensor.

Runs of zero in the irradiance columns are skipped, because every night is one.
"""
function check_constant_runs(md::MeteoData; minimum_run::Integer = 6)
    minimum_run >= 2 ||
        throw(ArgumentError("minimum_run must be at least 2, got $minimum_run"))

    flags = QCFlag[]
    for name in datacolumns(md)
        values = md.data[name]
        n = length(values)
        n >= minimum_run || continue
        exempt_zero = name in IRRADIANCE

        stuck = Int[]
        start = 1
        for i = 2:(n+1)
            same = i <= n && values[i] == values[start]
            same && continue
            len = i - start
            if len >= minimum_run && !(exempt_zero && iszero(values[start]))
                append!(stuck, start:(i-1))
            end
            start = i
        end
        isempty(stuck) || push!(
            flags,
            QCFlag(
                :constant_run,
                stuck,
                :warn,
                "$(name) holds the same value for $(minimum_run) or more records",
                name,
            ),
        )
    end
    return flags
end
