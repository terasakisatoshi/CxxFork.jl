# Advanced Interop Support Decision Design

## Summary

Issue `#10` should be handled as a support-surface cleanup for advanced interop features on the Julia `1.12` baseline, not as a broad legacy-compatibility restoration effort.

The repository already has an explicit `extended` verification lane and already treats C compiler mode as part of that lane. The remaining work is to make an intentional support decision for:

- `jpcpp"..."`
- `@cxxm`
- any advanced interop syntax that still exists in-tree but cannot be maintained with small, focused fixes

The goal is to keep the smallest advanced subset that remains stable on `macOS arm64 + Julia 1.12`, add explicit regression coverage for that subset, and replace ambiguous failures for unsupported paths with intentional error messages.

## Goals

- Define a supported advanced interop subset for the Julia `1.12` baseline.
- Keep `ctest` as the already-supported C compiler mode path in the `extended` lane.
- Promote a small, self-contained `jpcpp` subset into `extended` coverage if it remains stable with small fixes.
- Promote a small, self-contained `@cxxm` subset into `extended` coverage if it remains stable with small fixes.
- Replace ambiguous or generic unsupported-path failures with explicit, intentional errors.
- Align `README.md` and CI wording with the features and platforms that are actually validated.

## Non-Goals

- Restoring broad historical compatibility for all advanced or legacy interop syntax.
- Expanding support beyond the validated `macOS arm64 + Julia 1.12` primary lane.
- Taking on the separate `@cxx` assignment parser hole tracked in issue `#12`.
- Broad refactoring of unrelated legacy tests or runtime internals.

## Current State

The repository already has:

- a `core/*` baseline lane
- an `extended` lane
- `extended/ctest` registered in `test/testsuite_config.jl`
- legacy advanced interop coverage still living mostly in `test/jpcpp.jl` and `test/misc.jl`

This leaves the support story incomplete:

- some advanced interop paths may still work, but they are not part of the explicit verified lane
- unsupported paths are not consistently documented as unsupported
- failure modes include generic runtime errors such as `Unimplemented` or parser/internal failures that do not communicate product intent
- `README.md` currently says Linux and Windows are both CI smoke targets even though the current workflow only runs Linux smoke

## Design Principles

### 1. Support only what can be verified continuously

A feature path is only considered supported if all of the following are true:

- it passes as a self-contained test under `macOS arm64 + Julia 1.12`
- it fits naturally into the current `extended` lane
- its supported behavior can be described in a short README entry without caveats that dominate the description

If a path cannot meet those conditions with small, local fixes, it should not be carried as part of the supported surface.

### 2. Prefer a small honest surface over a broad implied one

For issue `#10`, the repository should intentionally support a narrow advanced subset rather than imply support through stale legacy tests. The output of this work should be:

- a clearly named supported subset
- focused tests for that subset
- explicit unsupported status for everything outside it

### 3. Unsupported paths must fail intentionally

If a path is retained in the parser or runtime but is not supported on the Julia `1.12` baseline, the failure should identify that fact directly. Users should not see generic `Unimplemented`, parser-shape errors, or other failures that look accidental when the real issue is an intentional support decision.

## Supported Subset Target

### C compiler mode

`ctest` is already in the `extended` lane and remains part of the supported advanced subset. This design does not change its support status.

### `jpcpp"..."`

The supported `jpcpp` subset is:

- passing a Julia mutable struct through `jpcpp"..."`
- using that value as a pointer to a matching C++ record in a simple call boundary

If this still works with no more than small fixes in `src/codegen.jl` and a focused regression test, it should remain supported and gain an explicit `extended` test target.

If even that minimal path proves unstable or requires larger runtime surgery, `jpcpp` should be documented as unsupported on the Julia `1.12` baseline and the failure should be made explicit.

### `@cxxm`

The supported `@cxxm` subset is:

- defining a free function in Julia with a simple return type and simple argument list
- defining a simple instance method with a supported receiver and straightforward return value

The initial validation target is the smallest subset represented by the legacy cases in `test/misc.jl`, not the full historical surface.

If these paths still work with small, local fixes in `src/cxxmacro.jl`, they should remain supported and move into explicit `extended` tests. If specific declaration forms or binding patterns remain unstable, they should fail with a deliberate unsupported-feature error instead of a generic parser or runtime failure.

## Unsupported Behavior Policy

Unsupported advanced interop behavior should be handled in one of two ways:

1. If the unsupported form is recognized at macro-entry or declaration-processing time, raise an explicit error that says the form is unsupported on the Julia `1.12` baseline.
2. If the unsupported form cannot be recognized cleanly until deeper runtime processing, intercept the most local stable failure point and replace generic errors with a message that makes the unsupported status clear.

The project should not silently keep ambiguous failure modes where the real product decision is "not supported."

Issue `#12` remains separate. The generic `Unimplemented` branch for `@cxx` assignment syntax is not part of the implementation scope for issue `#10`, even though this work follows the same philosophy for advanced interop paths that do fall under `#10`.

## File Responsibilities

### `src/codegen.jl`

- Keep or adjust the minimal `@jpcpp_str` path needed for the supported subset.
- Add explicit unsupported-path diagnostics if the minimal supported boundary cannot be crossed safely by broader forms.

### `src/cxxmacro.jl`

- Keep or adjust the minimal `@cxxm` declaration path needed for supported free-function and simple method definitions.
- Replace generic or misleading failures for unsupported `@cxxm` forms with explicit unsupported-feature errors where practical.

### `test/extended/*`

- Add focused, self-contained tests for the supported `jpcpp` subset.
- Add focused, self-contained tests for the supported `@cxxm` subset.
- Avoid promoting the entire historical `test/misc.jl` or `test/jpcpp.jl` files wholesale.

### `test/testsuite_config.jl`

- Register the new advanced interop tests inside the `extended` lane.

### `README.md`

- Document the supported advanced interop subset.
- Document unsupported advanced interop behavior where users would otherwise infer support from exported macros.
- Update the CI/platform wording so it matches the current workflow instead of implying a Windows smoke job that does not exist today.

### `.github/workflows/ci.yml`

- Keep the existing `macOS arm64` baseline and extended jobs.
- Keep Linux as the current smoke job.
- Do not imply Windows smoke coverage unless a Windows smoke job is actually restored in the workflow.

## Test Strategy

This work should follow a focused promotion pattern:

1. Start from the smallest legacy `jpcpp` and `@cxxm` cases that represent meaningful support.
2. Re-home those cases into dedicated `test/extended/*.jl` files.
3. Verify they fail before any runtime fix is added when behavior is currently broken.
4. Implement only the smallest runtime changes needed to make the promoted subset pass.
5. Leave broader legacy coverage out of the verified lane unless it is intentionally promoted in this same support decision.

Required validation for completion:

```bash
env JULIA_PKG_PRECOMPILE_AUTO=0 julia --project=. -e 'using Pkg; Pkg.build()'
julia --project=. --compiled-modules=no -e 'using Cxx'
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. -e 'using Pkg; Pkg.test(test_args=["extended","--jobs=1"])'
```

## Documentation and CI Alignment

The repository currently states that Linux and Windows are CI smoke targets, but the active workflow only runs Linux smoke. As part of issue `#10`, the support documentation should be brought back in line with the actual workflow.

The intended documentation state after this work is:

- `macOS arm64` remains the primary validated platform
- Linux remains the current smoke CI platform
- Windows is described as deferred or backlog platform work, not as an active current smoke lane
- the `extended` lane description includes the supported advanced interop subset that survives this work

This is a documentation correction, not a platform-support expansion.

## Acceptance Criteria

Issue `#10` is complete when all of the following are true:

- the supported advanced interop subset is explicitly defined
- supported `jpcpp` behavior, if any, has focused `extended` coverage
- supported `@cxxm` behavior, if any, has focused `extended` coverage
- unsupported advanced interop paths fail with intentional, comprehensible errors instead of generic failures
- `README.md` matches the actual advanced-interop and platform-validation story
- CI wording no longer implies a Windows smoke lane that is not currently configured

## Open Decision Already Resolved For This Design

This design assumes the following product decisions have already been made and should be implemented as written:

- keep only the smallest advanced subset that remains stable with small fixes
- preserve a supported feature when a small runtime/test/doc change is enough to keep it
- convert unsupported behavior to explicit errors rather than leaving ambiguous failures
- correct the README/CI wording mismatch in the same work item as issue `#10`
