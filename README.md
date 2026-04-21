# CxxFork.jl

CxxFork.jl is a maintained fork of `JuliaInterop/Cxx.jl` for modern Julia toolchains.

## Status

- Minimum supported Julia: `1.12`
- Verified locally: `macOS arm64` with `Pkg.build()`, `using Cxx`, the baseline `Pkg.test()` lane, and the opt-in extended lane
- CI smoke target: `Linux` and `Windows` with `Pkg.build()` and `using Cxx`
- Current CI intent: keep `macOS arm64` on a baseline lane plus a smaller extended lane, and keep Linux/Windows on smoke until broader runtime coverage is stabilized

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
- `Linux` and `Windows` are wired into CI as smoke targets, but are not yet feature-complete validation targets.
- The legacy C++ REPL pane, eager exception hook setup, and eager PCH generation are disabled by default in the modernized load path.

Optional environment flags:

- `CXX_ENABLE_REPL=1` enables the experimental C++ REPL integration
- `CXX_ENABLE_EXCEPTIONS=1` enables exception callback setup
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
- `extended/std_string` for verified `std::string` <-> Julia `String` conversions

Additional non-core suites should land here only after they are stable enough to validate continuously on `macOS arm64`.

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
- Linux and Windows are currently smoke-tested rather than fully runtime-validated.
- If `Pkg.test()` fails on a non-macOS platform, first check whether `Pkg.build()` and `using Cxx` succeed independently.

## Repository Development

For contributor workflow and agent guidance, see [AGENTS.md](AGENTS.md).
