# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

PVMeteo.jl is **pre-implementation**. `src/PVMeteo.jl` is still the template stub (`hello_world`), and
`test/test-basic-test.jl` tests only that stub. The real specification lives in **`pvmeteo-design.md`** —
treat it as the authoritative source for types, module layout, naming, and build order. Read it before
writing any `src/` code, and update it when a design decision changes during implementation. Note that
it is **gitignored on purpose** — it is a local working document, so never link to it from a tracked
file (the CI link checker fails on it) and do not assume a fresh clone has it.

There is no `docs/` directory and no Documenter site. The README is a short landing page; the
contributor and developer guide is `CONTRIBUTING.md`.

The repo was generated from [BestieTemplate.jl](https://github.com/JuliaBesties/BestieTemplate.jl)
(see `.copier-answers.yml`), but has since diverged from it (docs stack and all-contributors removed),
so a `copier update` will want to reintroduce those — reject those hunks.

## Commands

Julia 1.10+ is the compat floor. `Project.toml` declares a **workspace** (`projects = ["test"]`), so
`test/` is a separate environment that picks up the root package through `[sources]`.

```bash
# Full test suite
julia --project=. -e 'using Pkg; Pkg.test()'

# Lint + format everything (JuliaFormatter, markdownlint, yamlfmt, yamllint, cff)
pre-commit run -a

# Link check (same config CI uses)
lychee --no-progress --config .lychee.toml .
```

### Running a subset of tests

Tests use **TestItemRunner**, not a `Test.jl` include tree. `test/runtests.jl` is just
`@run_package_tests verbose=true`; every test lives in a `@testitem` block in a `test/test-*.jl` file,
with shared fixtures in `@testsnippet` / `@testmodule` blocks referenced via `setup=[...]`.

To filter, call `run_tests` with an explicit path rather than the `@run_package_tests` macro — from
`-e` the macro resolves its default path to the *parent* of the repo, which leaves the package name
empty and the test items then fail with `UndefVarError: PVMeteo not defined`:

```bash
# By tag (existing tags: :unit, :fast, :slow, :integration, :validation)
julia --project=test -e 'using TestItemRunner; TestItemRunner.run_tests("."; filter = ti -> :fast in ti.tags, verbose = true)'

# By name
julia --project=test -e 'using TestItemRunner; TestItemRunner.run_tests("."; filter = ti -> ti.name == "Basic functionality test")'
```

Each `@testitem` runs in its own module and must be self-contained: `PVMeteo` is injected
automatically, but anything else needs an explicit `using` inside the item or a `setup=[...]` module.
New test files must match `test-*.jl` to be discovered.

## Architecture constraints from the design

These are the invariants most likely to be violated by an otherwise reasonable change:

- **Layering.** PVMeteo is the data layer *beneath* the PV model chain. It must never import a chain
  type (e.g. `ChainSpec`). Anything requiring chain knowledge belongs in the consumer, not here.
- **Core dependencies are `Dates`, `Tables` and `SHA` only.** The design lists `CSV` too, but the EPW
  and TMY3 readers parse by hand and Aqua fails on the unused dep, so it was dropped. It comes back
  with the generic CSV reader. `HTTP`, `TimeZones`, `Parquet2`, `Arrow`, and `Makie` all go in package
  extensions under `ext/`. Keeping `TimeZones` out of the core is deliberate — users passing a plain
  `DateTime` should not pull TZJData.
- **`MeteoData` holds a `NamedTuple` of vectors, not a `DataFrame`,** so the element type `T` stays
  generic (`Float32`, `Dual`, `Particles`). Interop comes from implementing the Tables.jl interface.
- **Timestamps are UTC internally, always.** Local time is a boundary/presentation concern.
- **Interval labelling (`LeftLabeled`/`RightLabeled`/`CenterLabeled`) is a type parameter, not a keyword,**
  so a mismatch is a method error rather than a silent hour shift.
- **Units are SI, no `Unitful`** — enforced by documentation and tests.
- **Parsing never rejects data.** Readers report what they found and stash unknown fields in
  `meta.extra`; `validate` returns a `QCReport` and never mutates.
- **Every transform returns a new `MeteoData` and appends to `meta.lineage`.** Reproducibility is
  `content_hash` + `lineage`, not the source path.

`pvmeteo-design.md` §11 gives the intended build order (types → EPW/TMY3 readers → timestamp and
closure QC → `relabel`/`subset` → everything else) and §10 lists the invariants that tests must cover.

## Conventions

- Formatting: 4-space indent, **92-column margin**, LF endings (`.JuliaFormatter.toml`). Run the
  formatter through `pre-commit`; the config file itself is kept sorted+unique by a hook.
- Branch names are dash-separated imperative, prefixed with the issue number when one exists
  (`14-add-epw-reader`); otherwise use a `typo`/`hotfix`/`small-refactor` prefix for small changes.
- Commit messages use imperative present tense.
- Releases: bump `version` in `Project.toml`, move the `CHANGELOG.md` "Unreleased" section to
  `[x.y.z] - yyyy-mm-dd` with a new link at the bottom, merge, then comment `@JuliaRegistrator register`
  on the merge commit. Full procedure in `CONTRIBUTING.md`.
