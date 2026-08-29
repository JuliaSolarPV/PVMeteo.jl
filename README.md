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
> Under construction. The readers, container and column contract work today.
> Quality control and the transforms are next, and the package is not registered
> yet.

## Installation

```julia
julia> # press ]
pkg> add PVMeteo
```

## Reading a file

Readers take their metadata from the file's own header, so coordinates, elevation,
UTC offset and interval never have to be restated.

```julia
julia> using PVMeteo

julia> md = read_epw("NLD_De-Bilt.epw")
MeteoData{Float64}: 72 records, 2020-06-20T00:00:00 to 2020-06-22T23:00:00 UTC
  source:   epw (/data/NLD_De-Bilt.epw)
  interval: 1 hour, RightLabeled
  columns:  temp_air, relative_humidity, pressure, ghi, dni, dhi, wind_direction, wind_speed, precipitable_water, albedo
```

`read_tmy3` works the same way. Timestamps are converted to UTC on the way in, and
units are SI throughout, so TMY3 pressure arrives in Pa rather than mbar:

```julia
julia> t = read_tmy3("724666TYA.csv");

julia> t.meta.utc_offset, t.time[1], first(pressure(t))
(-300 minutes, DateTime("2020-06-20T06:00:00"), 101300.0)
```

## Columns

```julia
julia> columns(md)
(:temp_air, :relative_humidity, :pressure, :ghi, :dni, :dhi, :wind_direction, :wind_speed, :precipitable_water, :albedo)

julia> hascolumn(md, :dni), hascolumn(md, :snow_depth)
(true, false)

julia> round(sum(ghi(md)[1:24]) / 1000, digits = 2)   # kWh/m2 on day one
7.02
```

Accessors return views, so they alias the stored column rather than copying it.
Asking for a column the source does not carry fails at once and says what is
available, which is what lets a model chain reject an impossible configuration up
front instead of at hour 4317:

```julia
julia> dni(ghi_only)    # a source with no beam components
ERROR: ArgumentError: this MeteoData has no :dni column. Available columns: (:ghi, :temp_air)
```

## Interval labelling

The convention is a type parameter rather than a keyword, so mixing conventions is
a `MethodError` at the call site instead of a silent one-hour shift in the annual
total. EPW and TMY3 are both `RightLabeled`.

```julia
julia> md.meta.label
RightLabeled()

julia> typeof(md).parameters[3]
RightLabeled
```

## Element type

The container is generic in its element type, so `Float32`, `BigFloat`, dual
numbers and uncertainty types all pass through unboxed.

```julia
julia> read_epw("NLD_De-Bilt.epw"; T = Float32)  isa MeteoData{Float32}
true
```

## Interop and provenance

`MeteoData` implements the Tables.jl interface, with `time` as the first column, so
it feeds anything in that ecosystem without PVMeteo depending on DataFrames.

```julia
julia> using Tables

julia> Tables.schema(md).names
(:time, :temp_air, :relative_humidity, :pressure, :ghi, :dni, :dhi, :wind_direction, :wind_speed, :precipitable_water, :albedo)
```

Nothing a parser cannot map is discarded. Header lines and unmapped fields are kept
in `meta.extra`, and the source bytes are hashed so a result can be traced back to
the file that produced it.

```julia
julia> length(md.meta.extra), md.meta.content_hash
(27, 0x586f483a433e9ce8)
```

## How to Cite

If you use PVMeteo.jl in your work, please cite using the reference given in
[CITATION.cff](CITATION.cff).

## Contributing

Contributions of any kind are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) to get set up,
and please follow the [code of conduct](CODE_OF_CONDUCT.md).
