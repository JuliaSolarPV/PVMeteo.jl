# PVMeteo.jl

[![Test workflow status](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSolarPV/PVMeteo.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSolarPV/PVMeteo.jl)
[![Lint workflow Status](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Lint.yml?query=branch%3Amain)

PVMeteo.jl reads, validates and hands over the meteorological time series that photovoltaic
models run on. It is the data layer beneath the model chain, and it knows nothing about
simulation.

- Parsers for the formats that are actually distributed: EPW, TMY3, PVGIS, NSRDB, generic CSV
- Fetchers for public APIs, with checksummed caching
- One container type carrying the data **and** the metadata needed to interpret it
- Quality control specific to irradiance: component closure, BSRN limits, night-time nonzero,
  timestamp integrity
- Resampling, gap filling, interval relabelling, subsetting

Decomposition, transposition and clear-sky models are model chain stages, not data handling,
and live elsewhere.

> [!NOTE]
> Pre-implementation. The design is settled, the code is not written yet.

## Installation

```julia
julia> # press ]
pkg> add PVMeteo
```

## How to Cite

If you use PVMeteo.jl in your work, please cite using the reference given in
[CITATION.cff](CITATION.cff).

## Contributing

Contributions of any kind are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) to get set up,
and please follow the [code of conduct](CODE_OF_CONDUCT.md).
