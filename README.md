# CxxFork.jl

CxxFork.jl is a maintained fork of `JuliaInterop/Cxx.jl` for modern Julia toolchains.

## Status

- Minimum supported Julia: `1.12`
- Verified locally: `macOS arm64` with `Pkg.build()`, `using Cxx`, the baseline `Pkg.test()` lane, and the opt-in extended lane
- CI smoke target: `Linux` with `Pkg.build()` and `using Cxx`
- Current CI intent: keep `macOS arm64` on a baseline lane plus a smaller extended lane, keep Linux on smoke, and treat Windows as deferred smoke-support work until broader runtime coverage is stabilized

This repository is still a low-level C++/Julia integration package built on Clang/LLVM internals. Expect platform-sensitive behavior and prefer small, explicit validation steps when upgrading Julia, LLVM, or SDK versions.

## Installation

```julia
pkg> add https://github.com/terasakisatoshi/CxxFork.jl
pkg> build Cxx
```

Then:

```julia
julia> using Cxx
```

## Platform Notes

- `macOS arm64` is the primary implementation target right now.
- `Linux` is wired into CI as a smoke target.
- `Windows` remains a deferred smoke-support target and is not currently part of the active workflow.
- Advanced interop support on the Julia `1.12` baseline is intentionally narrow: C compiler mode and `jpcpp"..."` mutable-struct pointer bridging are the verified subset, while `@cxxm` currently reports an explicit unsupported error.
- The legacy C++ REPL pane and eager PCH generation are disabled by default in the modernized load path.
- C++ exception translation remains unsupported on the Julia 1.12 baseline. The old exception hook path still exists behind an environment flag, but current builds do not reliably translate C++ exceptions into Julia exceptions.

Optional environment flags:

- `CXX_ENABLE_REPL=1` enables the experimental C++ REPL integration
- `CXX_ENABLE_EXCEPTIONS=1` attempts to enable the legacy exception callback setup for debugging, but this path is not currently supported on Julia 1.12
- `CXX_ENABLE_PCH=1` enables eager PCH generation

These are off by default because they are not yet part of the stable Julia 1.12 baseline.

## Build Requirements

In addition to Julia itself, CxxFork builds a native shim against Clang/LLVM artifacts selected during `Pkg.build()`.

Practical requirements:

- a working Julia `1.12` installation
- a usable C/C++ toolchain for your platform
- standard SDK / developer tools for your OS

On macOS, Command Line Tools or Xcode must be installed. On Linux and Windows, expect the build to depend on the toolchain and SDK state exposed in CI.

## Validation

Recommended local validation after making changes:

```bash
env JULIA_PKG_PRECOMPILE_AUTO=0 julia --project=. -e 'using Pkg; Pkg.build()'
julia --project=. --compiled-modules=no -e 'using Cxx'
julia --project=. -e 'using Pkg; Pkg.test()'
```

The default `Pkg.test()` command runs the baseline lane only.

To run the smoke-only path explicitly:

```bash
julia --project=. --compiled-modules=no -e 'using Cxx'
```

To run the focused baseline subset explicitly:

```bash
julia --project=. -e 'using Pkg; Pkg.test(test_args=["core/simple_cxx","--jobs=1"])'
```

To run the current extended lane:

```bash
julia --project=. -e 'using Pkg; Pkg.test(test_args=["extended","--jobs=1"])'
```

Today the extended lane adds:

- `extended/ctest` for the C compiler mode path
- `extended/cxxm_basic` for the explicit Julia `1.12` unsupported diagnostic on `@cxxm`
- `extended/jpcpp_basic` for verified Julia mutable-struct to C++ record-pointer bridging through `jpcpp"..."`
- `extended/std_map_basic` for verified `std::map<std::string, std::string>` value/reference length and Julia `String` iteration, plus `std::map<int32_t, int32_t>` length/iteration coverage
- `extended/std_string` for verified `std::string` <-> Julia `String` conversions
- `extended/std_vector_basic` for verified `std::vector<int32_t>` creation, push, indexing, wrapping, and Julia `Vector{Int32}` conversion
- `extended/std_vector_wrappers` for verified `std::vector<std::string>` and `std::vector<bool>` read/wrap/Julia conversion paths

Additional non-core suites should land here only after they are stable enough to validate continuously on `macOS arm64`.

There is currently no supported exception-specific validation lane. Leave `CXX_ENABLE_EXCEPTIONS` disabled unless you are debugging the legacy exception runtime.

The test driver uses [`ParallelTestRunner.jl`](https://github.com/JuliaTesting/ParallelTestRunner.jl).

## Quick Example

```julia
using Cxx

cxx"""
int cxx_smoke_add(int x) {
    return x + 1;
}
"""

@assert @cxx(cxx_smoke_add(41)) == 42
@assert icxx"1 + 2;" == 3
```

## Legacy Examples

Most of the historical Cxx.jl usage model still applies:

- `@cxx foo(...)` for calling visible C++ functions
- `@cxx obj->method(...)` for member calls
- `cxx""" ... """` for declaring C++ code in the translation unit
- `icxx""" ... """` for embedding C++ snippets inside Julia code

Example:

```julia
using Cxx

cxx"""
#include <iostream>

void mycppfunction() {
    int z = 10 * 5 + 2;
    std::cout << "The number is " << z << std::endl;
}
"""

julia_function() = @cxx mycppfunction()
julia_function()
```

## Known Caveats

- The package still relies on internal Julia, Clang, and LLVM interfaces.
- CI may emit non-fatal LLVM module flag warnings during runtime-generated `llvmcall` paths.
- Linux is currently smoke-tested rather than fully runtime-validated, and Windows remains a deferred smoke-support target.
- If `Pkg.test()` fails on a non-macOS platform, first check whether `Pkg.build()` and `using Cxx` succeed independently.

## Repository Development

For contributor workflow and agent guidance, see [AGENTS.md](AGENTS.md).
