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

Every column has an accessor, `time` included.

```julia
julia> time(md)[1]
2020-06-20T00:00:00

julia> ghi(md)[12:14]
3-element Vector{Float64}:
 732.0
 739.0
 710.0
```

An accessor returns a view, so writing through it changes the stored column.

```julia
julia> typeof(ghi(md))
SubArray{Float64, 1, Vector{Float64}, Tuple{Base.Slice{Base.OneTo{Int64}}}, true}

julia> ghi(md)[13] = 0.0        # writes through
0.0

julia> md.data.ghi[13]
0.0
```

Asking for a column the source does not carry raises an error listing what it has.

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

## Transforms

`relabel` moves the timestamps to another convention. The values are untouched, because
relabelling says where an interval sits, not what was measured over it.

```julia
julia> left = relabel(md, LeftLabeled());

julia> md.time[1], left.time[1]
(DateTime("2020-06-20T00:00:00"), DateTime("2020-06-19T23:00:00"))
```

`subset` narrows to the half-open range `[t0, t1)` and copies the columns.

```julia
julia> day = subset(left, DateTime(2020, 6, 21), DateTime(2020, 6, 22))
MeteoData{Float64}: 24 records, 2020-06-21T00:00:00 to 2020-06-21T23:00:00 UTC
  source:   epw (/data/NLD_De-Bilt.epw)
  interval: 1 hour, LeftLabeled
  columns:  temp_air, relative_humidity, pressure, ghi, dni, dhi, wind_direction, wind_speed, precipitable_water, albedo
  lineage:  relabel -> subset
```

Every transform returns a new object and appends to `meta.lineage`. Together with
`meta.content_hash`, which identifies the bytes the data was read from, the lineage is
what reproduces a result.

```julia
julia> day.meta.lineage
2-element Vector{Symbol}:
 :relabel
 :subset
```

## Quality control

`validate` inspects the data and returns a `QCReport`. It never modifies its argument.

```julia
julia> validate(md)
QCReport: 72 records, 8 flags
  warn  constant_run on :pressure: 72 records. pressure holds the same value for 6 or more records
  ⋮
  info  skipped_needs_cosz: 0 records. the limit and closure checks need cos(zenith) at each record. Pass cosz to run them.
```

The BSRN limit checks and the closure test both need the cosine of the solar zenith angle
at each record. PVMeteo does not compute solar position, so pass a vector of `cos(z)` in.
Without it those two checks are skipped and the report says so, as the `info` line above
records.

```julia
julia> suspect = read_epw("suspect.epw");

julia> report = validate(suspect; cosz)
QCReport: 48 records, 8 flags
  error closure on :ghi: 6 records. ghi differs from dhi + dni * cos(zenith) by more than the tolerance
  ⋮
```

`apply` acts on a report. The `:mask` policy writes `NaN` at the flagged records of the
column each flag names.

```julia
julia> masked = apply(suspect, report);

julia> ghi(masked)[12:14]
3-element Vector{Float64}:
 NaN
 NaN
 NaN

julia> masked.meta.lineage
1-element Vector{Symbol}:
 :qc_mask
```

## Element type

The element type is generic. `Float32`, `BigFloat`, and even dual numbers or uncertainty
types are all supported.

```julia
julia> read_epw("NLD_De-Bilt.epw"; T = Float32) isa MeteoData{Float32}
true
```

## Tables.jl interface

Every `MeteoData` object is a column-oriented `Tables.jl` source.

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

This means you can also use `MeteoData` with any package that supports the `Tables.jl`
interface, such as `DataFrames.jl`.

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
