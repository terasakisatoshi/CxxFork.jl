# Cxx.jl Julia Modernization Design

**Date:** 2026-04-20

**Goal:** Restore a maintained path for `Cxx.jl` to run its core user-facing features on modern Julia, with `macOS arm64 + Julia 1.12` as the first required target and `Julia 1.10` evaluated immediately afterward as a compatibility extension.

## Summary

This repository currently targets Julia 1.3-era internals, uses `BinaryProvider`, vendors LLVM/Clang 6.0.1 assumptions, and mixes stable package behavior with experimental tooling such as the C++ REPL and LLVM-internal tests. That structure is not viable on modern Julia, especially on `macOS arm64`.

The modernization work will proceed in two phases:

1. Make `macOS arm64 + Julia 1.12` pass `build -> import -> core tests`.
2. Validate whether the same design can support `Julia 1.10` with a small compatibility layer. If that requires deep forks in bootstrap or Julia-internal integration, the package minimum Julia version will be set to `1.12`.

Linux and Windows are in scope for CI bring-up only during this phase. They must at least start build and smoke-test jobs, but they are not required to pass the full core suite yet.

## Product Scope

### Must work in this project phase

- `@cxx`
- `icxx`
- core Julia-to-C++ and C++-to-Julia type translation needed by those entry points
- the `std` wrapper layer used by `test/std.jl`
- package build and load on `macOS arm64 + Julia 1.12`
- a clear go/no-go decision for `Julia 1.10`

### Explicitly de-prioritized in this project phase

- the C++ REPL pane in `src/CxxREPL/replpane.jl`
- LLVM/Clang internal exploration tests such as `llvmtest.jl`, `llvmgraph.jl`, and `clangutils.jl`
- Qt-specific tests
- preserving every internal or experimental behavior if it blocks the core scope above

These features are not being deleted by design, but they are allowed to be disabled, split out, or excluded from the core CI lane while the core package is stabilized.

## Compatibility Targets

### Required target

- `macOS arm64 + Julia 1.12`

### Conditional target

- `macOS arm64 + Julia 1.10`

`Julia 1.10` remains a target only if the package can support it with a local compatibility layer around Julia internals. If the required changes spill into broad bootstrap forks, divergent code generation paths, or version-specific C++ shims, the minimum supported Julia version becomes `1.12`.

### Bring-up targets for this phase

- `Linux`
- `Windows`

For Linux and Windows, success in this phase means CI jobs exist and reach build or smoke-test execution. Full support is deferred until the macOS core lane is stable.

## Current Technical Constraints

The current codebase has four structural blockers:

1. `Project.toml` restricts Julia to `~1.3` and still depends on `BinaryProvider`.
2. `deps/build.jl` and `deps/build_libcxxffi.jl` assume outdated binary distribution and platform detection.
3. `deps/BuildBootstrap.Makefile` and `src/bootstrap.cpp` are written around LLVM/Clang 6.0.1-era headers and Julia runtime integration details.
4. Julia internals are referenced directly from multiple Julia source files, especially `src/cxxstr.jl`, instead of through a controlled compatibility boundary.

The design must remove or isolate each of these blockers before broad CI support is realistic.

## Architecture

### 1. Build system modernization

The package will stop relying on `BinaryProvider`. The modernized build path must:

- support current platform detection on `macOS arm64`
- prepare `deps/path.jl` or its equivalent local configuration data without assuming an old Julia layout
- build or acquire `libcxxffi` through a mechanism that works on Julia 1.12
- expose build failures as build failures, not as downstream runtime errors

The implementation is free to replace the current dependency acquisition mechanism entirely. Preserving the old `BinaryProvider` pipeline is not a goal.

### 2. `libcxxffi` as the central integration boundary

The core package behavior depends on `libcxxffi`. Phase 1 treats this boundary as the primary technical milestone:

- `src/bootstrap.cpp` must compile on the chosen toolchain for `macOS arm64 + Julia 1.12`
- the produced library must load from Julia
- the exported functions used by `src/clangwrapper.jl`, `src/codegen.jl`, `src/cxxstr.jl`, and `src/initialization.jl` must support the core test suite

Where needed, bootstrap code may be modernized aggressively. Compatibility is required at the package API level, not at the old internal implementation level.

### 3. Julia-internal compatibility layer

Calls into Julia internals will be consolidated behind a dedicated compatibility boundary. That layer will own:

- method lookup helpers
- type inference helpers
- access to LLVM function declarations or equivalent compiled entry points
- version branching between Julia 1.10 and 1.12 where unavoidable

The rest of the package should call a narrow internal API rather than directly reaching into `Base`, `Core.Compiler`, or `libjulia` symbols. This limits the blast radius of version-specific logic and makes the 1.10 viability check explicit.

### 4. Optional and experimental feature isolation

The C++ REPL and LLVM/Clang exploration features will be isolated from the core load path. They must not block:

- `Pkg.build()`
- `using Cxx`
- the core test lane

If necessary, they may be guarded behind feature checks, version checks, or separate test groups.

## Runtime Flow

The stabilized runtime should follow this path:

1. `Pkg.build()` resolves and prepares the `libcxxffi` dependency for the current platform.
2. package load in `src/Cxx.jl` initializes only the required compiler/runtime pieces for core operation
3. `@cxx` and `icxx` route through a compatibility-aware Julia integration layer
4. generated code and clang interaction pass through the modernized `libcxxffi` boundary
5. optional REPL and experimental tooling initialize only when explicitly enabled and supported

This flow keeps the package usable even if experimental features are unavailable on a given platform or Julia version.

## Testing Strategy

The test suite will be reorganized around `ParallelTestRunner.jl`.

### Test runner contract

`test/runtests.jl` will stop manually `include`-ing every test file. Instead it will use `ParallelTestRunner.runtests(Cxx, ARGS)` so each file under `test/` executes in an isolated process and can run in parallel.

### Required test organization changes

To support isolated parallel execution:

- each test file must be self-sufficient
- shared setup must live in a small helper module or helper file with explicit imports
- test files must avoid relying on mutable global state shared across files
- C++ declaration names, temporary files, and environment mutations must not collide between concurrently running test processes

### Core lane

The required core lane for this project phase covers:

- `test/cxxstr.jl`
- `test/icxxstr.jl`
- `test/ctest.jl`
- the subset of `test/misc.jl` needed for A-scope behavior
- `test/std.jl`

If `test/misc.jl` contains checks that are really experimental or LLVM-internal, those checks should be moved into non-core files instead of keeping the whole file in the required lane.

### Experimental lane

The following tests are outside the required pass criteria for this phase and should be separated accordingly:

- `test/llvmtest.jl`
- `test/llvmgraph.jl`
- `test/clangutils.jl`
- `test/qttest.jl`
- REPL-specific tests or future REPL coverage

## CI Strategy

CI will be split into purpose-specific jobs instead of one undifferentiated lane.

### Required CI job

- `macOS arm64 + Julia 1.12`
  This job must run `build -> import -> core tests` and must pass.

### Evaluation CI job

- `macOS arm64 + Julia 1.10`
  This job determines whether 1.10 support is viable with the same architecture. It is a product decision job, not an indefinite compatibility promise.

### Bring-up jobs

- `Linux`
- `Windows`

These jobs should be added now, but they only need to reach build and smoke-test execution during this phase. Their failures should be attributable to platform-specific work still pending, not to the absence of CI coverage.

### CI command model

CI should exercise the same public commands used locally:

- package build
- `using Cxx`
- `julia --project=test -e 'using ParallelTestRunner; ...'` or the repository-equivalent command path for parallel tests

The CI surface must not depend on hidden local setup.

## Error Handling and Diagnostics

Failures must be classified at the boundary where they occur:

- dependency or artifact acquisition failures are build failures
- `libcxxffi` compile or link failures are native build failures
- package initialization failures are import/runtime failures
- code generation or C++ execution mismatches are test/runtime failures

This separation matters because Phase 2 depends on understanding whether Julia 1.10 fails at the build layer or at the Julia-internal integration layer.

The build and test pipelines should therefore emit concise diagnostics that make the failing stage obvious.

## Phase Gates

### Phase 1 completion criteria

All of the following must hold on `macOS arm64 + Julia 1.12`:

- `Pkg.build()` succeeds
- `using Cxx` succeeds
- the core `ParallelTestRunner` lane passes

### Phase 2 decision criteria for Julia 1.10

`Julia 1.10` support is accepted only if:

- the differences from 1.12 are handled inside a localized compatibility layer
- `src/bootstrap.cpp` does not require a substantially separate implementation path
- core features do not depend on version-specific behavior scattered across the codebase

If those criteria are not met, the repository should update its supported Julia floor to `1.12` and stop advertising 1.10 as a target.

## File-Level Impact Areas

The following files are expected to be central during implementation:

- `Project.toml`
- `deps/build.jl`
- `deps/build_libcxxffi.jl`
- `deps/BuildBootstrap.Makefile`
- `src/bootstrap.cpp`
- `src/Cxx.jl`
- `src/initialization.jl`
- `src/cxxstr.jl`
- `src/codegen.jl`
- `src/clangwrapper.jl`
- `test/runtests.jl`
- `test/*.jl` in the core lane
- `.github/workflows/*`

Additional support files may be added for compatibility helpers, test helpers, and CI configuration.

## Decisions Locked In

- `Julia 1.12` is the first required modern target.
- `Julia 1.10` is a follow-up validation target, not an unconditional requirement.
- `macOS arm64` is mandatory in this implementation phase.
- Linux and Windows are CI bring-up targets in this phase.
- `BinaryProvider` is not part of the future architecture.
- `ParallelTestRunner.jl` is the required test execution model.
- REPL and LLVM-internal experimentation are non-blocking for the first stabilization pass.
