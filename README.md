# PVMeteo.jl

[![Test workflow status](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSolarPV/PVMeteo.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSolarPV/PVMeteo.jl)
[![Lint workflow Status](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Lint.yml?query=branch%3Amain)

`PVMeteo.jl` reads, validates and supplies meteorological time series data to support
simulating of solar photovoltaic systems.

- Parsers for the following formats: EPW, TMY3, PVGIS, NSRDB, generic CSV
- Common fetchers for public APIs, with checksummed caching
- Convenient container type for carrying the data and the metadata
- Automatic quality control specific to irradiance data
- Resampling, gap filling, interval relabelling, subsetting

## Installation

Not registered yet, so install from GitHub.

```julia
julia> # press ]
pkg> add https://github.com/JuliaSolarPV/PVMeteo.jl
```

## Reading a file

Metadata comes from the file header. Timestamps are converted to UTC and units are SI.

```julia
julia> using PVMeteo

julia> md = read_epw("NLD_De-Bilt.epw")
MeteoData{Float64}: 72 records, 2020-06-20T00:00:00 to 2020-06-22T23:00:00 UTC
  source:   epw (/data/NLD_De-Bilt.epw)
  interval: 1 hour, RightLabeled
  columns:  temp_air, relative_humidity, pressure, ghi, dni, dhi, wind_direction, wind_speed, precipitable_water, albedo
```

`read_tmy3` reads NREL TMY3 files. Pressure is given in Pa.

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

Accessors return views. A missing column raises an error listing the available columns.

```julia
julia> dni(ghi_only)
ERROR: ArgumentError: this MeteoData has no :dni column. Available columns: (:ghi, :temp_air)
```

## Interval labelling

The labelling convention is part of the type. A function written for one convention
raises a `MethodError` when given another. EPW and TMY3 are `RightLabeled`.

```julia
julia> md.meta.label, typeof(md).parameters[3]
(RightLabeled(), RightLabeled)
```

## Element type

The element type is generic. `Float32`, `BigFloat`, and even dual numbers or uncertainty
types are all supported.

```julia
julia> read_epw("NLD_De-Bilt.epw"; T = Float32) isa MeteoData{Float32}
true
```

## Tables.jl interface

`MeteoData` implements the Tables.jl interface, with `time` always as the first column.

```julia
julia> using Tables

julia> Tables.schema(md).names
(:time, :temp_air, :relative_humidity, :pressure, :ghi, :dni, :dhi, :wind_direction, :wind_speed, :precipitable_water, :albedo)
```

## How to Cite

If you use PVMeteo.jl in your work, please cite using the reference given in
[CITATION.cff](CITATION.cff).

## Contributing

Contributions of any kind are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) to get set up,
and please follow the [code of conduct](CODE_OF_CONDUCT.md).
