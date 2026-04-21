# String-Key std::map Iteration Design

**Date:** 2026-04-21

**Goal:** Resolve the remaining `std::map<std::string, std::string>` limitation from `#20` without broadening public `const std::string` support beyond what is needed for the validated `macOS arm64 + Julia 1.12` lane.

## Summary

`#17` stabilized `std::map` template translation and validated `std::map<int32_t, int32_t>` length and iteration. The remaining gap is the string-key path: `std::map<std::string, std::string>` can report `length`, but iterating the map and converting keys or values to Julia `String` is still not stable enough to claim support.

The core issue is that `std::map` iteration yields a `const K` key. For `K = std::string`, a naive attempt to widen `String` conversion to `const std::string` and `const std::string&` caused instability around destruction/finalization. This work therefore must avoid turning that wider conversion into a general public API promise.

The design is to keep the fix local to the `std::map` iteration path: when iteration encounters a string-key/string-value map, normalize the returned pair into non-const `std::string` values that are already supported by the existing `String` conversion path. That makes string-key map iteration usable without widening the general `String(::const std::string)` surface.

## Alternatives Considered

### 1. Local normalization in `std::map` iteration

- detect the string-key/string-value map path inside `CxxStd` map iteration
- return supported `std::string` copies for key and value
- keep the existing public `String(::std::string)` and `String(::std::string&)` contract unchanged

This is the recommended option. It is the smallest change that closes `#20`, keeps the risk surface small, and avoids repeating the previous crash path.

### 2. `std::map<std::string, std::string>`-specific iterate overload

- add a special-case `iterate` implementation for one explicit map instantiation

This is more brittle than local normalization because it introduces a dedicated type-specialized path for a single map form while leaving the rest of the generic map wrapper unchanged.

### 3. General `const std::string` conversion support

- make `String` and `convert(String, ...)` work for `const std::string` and `const std::string&` everywhere

This is a larger API decision and was already shown to have finalizer/destruction risk when attempted naively. It is out of scope for `#20` and should remain a separate future decision.

## Scope

### In scope

- make `std::map<std::string, std::string>` iteration stable enough for the extended verification lane
- ensure iterated keys and values can be converted to Julia `String`
- preserve the supported `std::map<int32_t, int32_t>` path from `#17`
- update README wording once the support is actually verified

### Out of scope

- general public support for `String(::const std::string)` or `convert(String, ::const std::string&)`
- new `std::map` mutation APIs
- unrelated cleanup in `std::vector` or `std::string`

## Design

### Iteration behavior

The generic `std::map` iterator in `src/std.jl` remains the single supported iteration entry point. The implementation will be adjusted so that the string-key map path does not leak `const std::string` values into Julia-facing `String` conversion.

The intended behavior is:

1. `iterate(map)` still drives off the C++ iterator returned by `begin()`.
2. For ordinary map instantiations such as `std::map<int32_t, int32_t>`, the current behavior is preserved.
3. For the string-key/string-value path, the returned pair is normalized to supported `std::string` values before Julia conversion occurs.

This keeps the fix local to the map wrapper and avoids changing the supported meaning of `String(x)` for unrelated `const std::string` values returned elsewhere in the package.

### Public API contract

After this change, the supported claim is:

- `std::map<std::string, std::string>` supports `length`
- iterating that map supports converting keys and values to Julia `String`

The supported claim is explicitly not:

- any `const std::string` returned from any API surface can be converted to Julia `String`

That broader promise remains deferred.

## Testing

The work must follow a red-green cycle.

### Failing test to add first

Extend `test/extended/std_map_basic.jl` so that:

- a `std::map<std::string, std::string>` fixture is iterated
- both keys and values are converted to Julia `String`
- the resulting collection matches the expected contents

This test must fail on the current baseline before any implementation change is accepted.

### Passing criteria

The following must pass after the fix:

- `env JULIA_PKG_PRECOMPILE_AUTO=0 julia --project=. -e 'using Pkg; Pkg.build()'`
- `julia --project=. --compiled-modules=no -e 'using Cxx'`
- `julia --project=. -e 'using Pkg; Pkg.test()'`
- `julia --project=. -e 'using Pkg; Pkg.test(test_args=["extended","--jobs=1"])'`

## Risks and Guardrails

- The main risk is reintroducing the earlier finalizer/destruction instability seen when `const std::string` support was widened directly.
- To limit that risk, the fix must stay local to `std::map` iteration and must not broaden the general `String` conversion API.
- If the smallest local change still forces broader string conversion semantics, the work should stop and the design should be revisited rather than silently expanding scope.
