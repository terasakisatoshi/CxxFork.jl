# C++ Exception Opt-In Lane Design

**Date:** 2026-04-21

**Issue:** `#7` Stabilize opt-in C++ exception translation for the Julia 1.12 baseline

## Summary

`CXX_ENABLE_EXCEPTIONS=1` currently enables a Julia callback that translates C++ exceptions into `CxxException{...}` values during package initialization, but that path is outside the validated baseline and only covered by legacy tests.

This work will keep exception translation opt-in and add an explicit verification lane for it on `macOS arm64 + Julia 1.12`. The goal is not to make exception translation default-on in this phase. The goal is to define a narrow, honest support contract for the opt-in path and validate the supported subset continuously.

## Supported Scope

This design treats the following as the supported opt-in exception surface on the primary platform:

- enabling exception translation with `CXX_ENABLE_EXCEPTIONS=1` before `using Cxx`
- translation of a built-in thrown value into a Julia-visible `CxxException`
- custom formatting through `@exception function showerror(...)`
- formatting of `std::length_error` through the existing standard-library helper path

Support is validated only on `macOS arm64 + Julia 1.12` in this phase.

## Explicit Non-Goals

This design does not:

- make exception translation enabled by default
- promise Linux or Windows support beyond current smoke-only status
- broaden exception handling into the baseline `Pkg.test()` lane
- redesign the ABI-sensitive callback machinery in `src/exceptions.jl`
- guarantee every historical exception behavior from `test/misc.jl` or `test/std.jl`

## Design

### 1. Dedicated opt-in verification lane

Exception coverage will live in its own lane rather than the existing `extended` lane.

That lane exists for one reason: it requires a process-level environment flag before `using Cxx`, so it has a different runtime contract from the ordinary extended suites. Keeping it separate avoids making `extended` silently depend on environment preparation and keeps the support story easy to explain.

The lane should be invokable with a dedicated test argument and documented as an opt-in validation command.

### 2. Narrow supported test surface

The dedicated exception lane will validate only a small, self-contained subset:

- a thrown built-in value
- a user-defined C++ exception with Julia-side `@exception` formatting
- `std::length_error` formatting through a standard-library failure path

Those three behaviors cover the current user-visible exception translation story without reopening the entire historical `misc.jl` and `std.jl` suites.

### 3. Documentation contract

`README.md` will distinguish three classes of runtime behavior:

- baseline validation
- general extended validation
- exception-specific opt-in validation

The docs must state that exception translation remains disabled by default, requires `CXX_ENABLE_EXCEPTIONS=1` before `using Cxx`, and is supported only on `macOS arm64 + Julia 1.12` for now.

### 4. Failure model

The opt-in lane should fail clearly when exception translation is not enabled. The intended behavior is not to silently skip the test body after import; the runner and docs should make the requirement explicit so a user can tell whether they ran the right lane under the right environment.

This work does not attempt to invent a cross-platform fallback. If unsupported environments fail or remain unvalidated, the documentation should say so directly.

## Runtime Flow

The supported exception opt-in path should be understood as:

1. user starts Julia with `CXX_ENABLE_EXCEPTIONS=1`
2. `using Cxx` loads the package
3. `CxxExceptionInit.__init__()` registers `setup_exception_callback()`
4. C++ exceptions that cross the Cxx boundary are translated into `CxxException{...}`
5. `showerror` dispatch, including `@exception` specializations, formats the resulting Julia exception

## Testing Strategy

Testing should use new self-contained files under `test/` rather than relying on the broad legacy suites.

The lane should validate:

- import under `CXX_ENABLE_EXCEPTIONS=1`
- built-in thrown value formatting
- user-defined exception formatting with `@exception`
- `std::length_error` formatting

The baseline `Pkg.test()` lane remains unchanged. The ordinary `extended` lane also remains unchanged.

## Acceptance Criteria

This design is complete when:

- the repository has a distinct exception opt-in test lane
- that lane passes on `macOS arm64 + Julia 1.12`
- `README.md` explains how to run it and what it does not guarantee
- exception translation remains opt-in by design rather than accidentally enabled

## Relevant Files

- `src/Cxx.jl`
- `src/exceptions.jl`
- `src/initialization.jl`
- `src/std.jl`
- `test/misc.jl`
- `test/std.jl`
- `test/testsuite_config.jl`
- `test/runtests.jl`
- `README.md`
