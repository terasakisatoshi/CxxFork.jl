# AGENTS.md

Repository guidance for coding agents and automated contributors.

## Branching

- Do not work directly on `master`.
- Prefer a dedicated feature branch.
- Prefer a git worktree for isolated work.

## Baseline

- Assume Julia `1.12` is the current minimum supported version.
- Before claiming a fix, run `Pkg.build()` at least once in the working tree.
- Treat `macOS arm64` as the primary validated platform.
- Treat `Linux` and `Windows` as smoke-CI targets unless the task explicitly expands platform coverage.

## Default Verification

Run these after substantive changes:

```bash
env JULIA_PKG_PRECOMPILE_AUTO=0 julia --project=. -e 'using Pkg; Pkg.build()'
julia --project=. --compiled-modules=no -e 'using Cxx'
julia --project=. -e 'using Pkg; Pkg.test()'
```

If a change is narrowly scoped to smoke coverage, this is the minimum acceptable verification:

```bash
env JULIA_PKG_PRECOMPILE_AUTO=0 julia --project=. -e 'using Pkg; Pkg.build()'
julia --project=. --compiled-modules=no -e 'using Cxx'
```

## CI Intent

- `macOS arm64`: full lane, including `Pkg.test()`
- `Linux`: smoke lane, `Pkg.build()` + `using Cxx`
- `Windows`: smoke lane, `Pkg.build()` + `using Cxx`

Do not silently promote Linux or Windows to full runtime coverage without updating CI, README, and any related plan/spec documents together.

## Editing Guidance

- Keep changes tightly scoped.
- Preserve user changes already present in the worktree.
- Update `README.md` when platform support, setup, or verification expectations change.
- Prefer documenting residual platform limitations explicitly instead of implying support that is not yet validated.

## Current Caveats

- The package still depends on Julia/LLVM/Clang internals.
- Runtime-generated LLVM may still emit non-fatal module-flag warnings.
- Experimental features like the REPL pane, eager exception hooks, and eager PCH are intentionally off by default in the Julia 1.12 baseline.
