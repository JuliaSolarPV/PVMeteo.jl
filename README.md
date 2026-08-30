# PVMeteo.jl

[![Test workflow status](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Lint workflow Status](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/PVMeteo.jl/actions/workflows/Lint.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSolarPV/PVMeteo.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSolarPV/PVMeteo.jl)

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

Metadata comes from the file header, timestamps are automatically converted to UTC and
units are always in SI.

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

Readers map each source onto a fixed set of canonical columns, always in SI units.

| Column | Quantity | Unit |
|:---|:---|:---|
| `:ghi` | global horizontal irradiance | W/m2 |
| `:dni` | direct normal irradiance | W/m2 |
| `:dhi` | diffuse horizontal irradiance | W/m2 |
| `:temp_air` | air temperature | degC |
| `:wind_speed` | wind speed | m/s |
| `:wind_direction` | wind direction | deg |
| `:pressure` | air pressure | Pa |
| `:relative_humidity` | relative humidity | % |
| `:albedo` | surface albedo | dimensionless |
| `:precipitable_water` | precipitable water | cm |

Anything a reader cannot map to one of these is kept in `md.meta.extra`.

`time` is the one column guaranteed to exist. It is always present, always in UTC,
and always the first column of the table. Every canonical column above is optional,
so `hascolumn` reports what a given source actually carries.

```julia
julia> using Tables

julia> Tables.columnnames(md)
(:time, :temp_air, :relative_humidity, :pressure, :ghi, :dni, :dhi, :wind_direction, :wind_speed, :precipitable_water, :albedo)

julia> hascolumn(md, :dni), hascolumn(md, :snow_depth)
(true, false)

julia> round(sum(ghi(md)[1:24]) / 1000, digits = 2)   # kWh/m2 on day one
7.02
```

Every column has an accessor, `time` included, and they return views. A missing column raises an error listing the available columns.

```julia
julia> dni(ghi_only)
ERROR: ArgumentError: this MeteoData has no :dni column. Available columns: (:ghi, :temp_air)
```

## Interval labelling

The label says where a timestamp sits for a given interval:

| Label | Timestamp | 10:00 hourly covers |
|:---|:---|:---|
| `LeftLabeled` | start of the interval | 10:00 to 11:00 |
| `RightLabeled` | end of the interval | 09:00 to 10:00 |
| `CenterLabeled` | middle of the interval | 09:30 to 10:30 |

The convention is part of the type. A function written for one convention raises a
`MethodError` when given another. EPW and TMY3 are `RightLabeled`.

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

`MeteoData` is a column-oriented `Tables.jl` source. Five methods are implemented.

| Method | Result |
|:---|:---|
| `Tables.istable` | `true` |
| `Tables.columnaccess` | `true` |
| `Tables.columns` | a `NamedTuple` of the columns, `time` first |
| `Tables.columnnames` | the column names, `time` first |
| `Tables.schema` | the names and types, without touching the data |

```julia
julia> using Tables

julia> keys(Tables.columns(md))
(:time, :temp_air, :relative_humidity, :pressure, :ghi, :dni, :dhi, :wind_direction, :wind_speed, :precipitable_water, :albedo)

julia> Tables.columns(md).ghi[13]
739.0

julia> Tables.schema(md)
Tables.Schema:
 :time                Dates.DateTime
 :temp_air            Float64
 :relative_humidity   Float64
 :ghi                 Float64
 ⋮
```

This means you can also use `MeteoData` with any package that supports the `Tables.jl` interface, such as `DataFrames.jl`.

```julia
julia> using DataFrames

julia> df = DataFrame(md);
```

## How to Cite

If you use PVMeteo.jl in your work, please cite using the reference given in
[CITATION.cff](CITATION.cff).

## Contributing

Contributions of any kind are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) to get set up,
and please follow the [code of conduct](CODE_OF_CONDUCT.md).
