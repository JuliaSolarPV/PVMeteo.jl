# Contributing

Thanks for the interest. We welcome all kinds of contribution: code, documentation, examples,
configuration, issue reports. Be polite and respectful, and follow the
[code of conduct](CODE_OF_CONDUCT.md).

If you think you found a bug, or have a focused suggestion, open an
[issue](https://github.com/JuliaSolarPV/PVMeteo.jl/issues). Before opening a pull request,
start an issue or a discussion on the topic. If you found an issue that interests you,
comment on it with your plans; if the solution is clear, go straight to a pull request.

## First time clone

If you have writing rights you can clone directly and skip the fork; wherever **upstream** is
mentioned below, use **origin** instead.

1. Fork this repo
2. Clone your fork (this creates a `git remote` called `origin`)
3. Add this repo as a second remote:

   ```bash
   git remote add upstream https://github.com/JuliaSolarPV/PVMeteo.jl
   ```

You push branches to `origin` and update your local `main` from `upstream`.

## Testing

```julia-repl
julia> # press ]
pkg> activate .
pkg> test
```

Tests use [TestItemRunner](https://github.com/julia-vscode/TestItemRunner.jl): each test lives
in a `@testitem` block inside a `test/test-*.jl` file, and `test/runtests.jl` only collects
them. To run a subset without going through `Pkg.test`:

```bash
# By tag
julia --project=test -e 'using TestItemRunner; TestItemRunner.run_tests("."; filter = ti -> :fast in ti.tags, verbose = true)'

# By name
julia --project=test -e 'using TestItemRunner; TestItemRunner.run_tests("."; filter = ti -> ti.name == "Basic functionality test")'
```

## Linting and formatting

Install an [EditorConfig](https://editorconfig.org) plugin for your editor so the basic
formatting settings are picked up automatically.

Linters and formatters run through [pre-commit](https://pre-commit.com). Julia code is
formatted with [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl), so install
that globally first:

```julia-repl
julia> # press ]
pkg> activate
pkg> add JuliaFormatter
```

Then install `pre-commit` (we recommend [pipx](https://pipx.pypa.io)) and activate the hook:

```bash
pipx install pre-commit
pre-commit install
```

To run everything manually:

```bash
pre-commit run -a
```

CI also runs a link check with [lychee](https://github.com/lycheeverse/lychee). To reproduce
it locally:

```bash
lychee --no-progress --config .lychee.toml .
```

## Working on a new issue

We keep a linear history, so keep your branches up to date.

1. Fetch from the remote and fast-forward your local main:

   ```bash
   git fetch upstream
   git switch main
   git merge --ff-only upstream/main
   ```

2. Branch from `main` to address the issue:

   ```bash
   git switch -c 42-add-answer-universe
   ```

3. Push the new local branch to your fork:

   ```bash
   git push -u origin 42-add-answer-universe
   ```

4. Open a pull request against the org's `main`.

**Branch naming.** Use dash-separated imperative wording and prefix it with the issue number
when there is one (`14-add-tests`, `15-fix-model`, `16-remove-obsolete-files`). For small
changes with no issue, use a prefix such as `typo`, `hotfix` or `small-refactor`. If the
changes are not small and there is no issue, create the issue first so we can discuss it.

**Commit messages.** Imperative or present tense ("Add feature", "Fix bug"), informative
titles, a body when the details warrant it, and a note when there are breaking changes. Aim
for atomic commits (recommended reading:
[The Utopic Git History](https://blog.esciencecenter.nl/the-utopic-git-history-d44b81c09593)).

**Before opening the pull request.** Make sure the tests and the pre-commit hooks pass, and
rebase onto the latest upstream `main` if necessary:

```bash
git fetch upstream
git rebase upstream/main BRANCH_NAME
```

## Making a new release

- Create a branch `release-x.y.z`
- Update `version` in `Project.toml`
- Update `CHANGELOG.md`:
  - Rename the "Unreleased" section to "[x.y.z] - yyyy-mm-dd" (version in brackets, dash, ISO date)
  - Add a fresh "Unreleased" section above it
  - Add a link for version "x.y.z" at the bottom, and point the "[unreleased]" link at
    `vx.y.z ... HEAD`
- Commit as "Release vx.y.z", push, open a PR, wait for CI, merge
- Open the [latest commit](https://github.com/JuliaSolarPV/PVMeteo.jl/commit/main) and comment
  `@JuliaRegistrator register` at the bottom

Then wait and verify: the bot comments (under a minute) with a link to a registry PR;
auto-merge should follow shortly; once merged, TagBot creates the GitHub tag, which shows up
under [releases](https://github.com/JuliaSolarPV/PVMeteo.jl/releases).
