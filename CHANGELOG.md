# CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog],
and this project adheres to [Semantic Versioning].

## [Unreleased]

### Added

- `MeteoData`, a container holding a UTC `time` vector, a `NamedTuple` of equal-length
  `Vector{T}` columns, and a `MeteoMeta` describing the source.
- `MeteoMeta`, carrying coordinates, UTC offset, interval, interval label, provenance
  and everything a reader could not map to a canonical column.
- `IntervalLabel` and the `LeftLabeled`, `RightLabeled` and `CenterLabeled` conventions,
  carried as a type parameter so a mismatch is a method error.
- The canonical column contract, an accessor per column, and `hascolumn`.
- The Tables.jl column interface, with `time` as the first column.
- `read_epw` and `read_tmy3`.
- `validate`, returning a `QCReport` of `QCFlag` findings. Covers timestamp
  monotonicity, duplicates, gaps and spacing, stuck sensors, the BSRN physical and
  extremely rare limits, and closure of GHI against DNI and DHI.
- `apply`, which acts on a report. The `:mask` policy writes `NaN` at the flagged
  records.
- `relabel` and `subset`, each returning a new object and appending to `meta.history`.

<!-- Links -->

[keep a changelog]: https://keepachangelog.com/en/1.1.0/
[semantic versioning]: https://semver.org/spec/v2.0.0.html

<!-- Versions -->

[unreleased]: https://github.com/JuliaSolarPV/PVMeteo.jl/compare/v0.1.0...HEAD
