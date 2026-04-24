# CxxFork.jl - The Julia C++ FFI

CxxFork.jl is a maintained fork of `JuliaInterop/Cxx.jl` for modern Julia
toolchains. It provides a C++ interoperability interface for Julia and keeps the
legacy experimental C++ REPL path available behind an opt-in environment flag.

## Functionality

There are two ways to access the main functionality provided by
this package. The first is using the `@cxx` macro, which puns on
Julia syntax to provide C++ compatibility.
Additionally, this package provides the `cxx""` and `icxx""` custom
string literals for inputting C++ syntax directly. The two string
literals are distinguished by the C++ level scope they represent.
See the API documentation for more details.

## Installation

The current baseline is Julia `1.12`. `macOS arm64` is the primary validated
platform; Linux is smoke-tested with `Pkg.build()` and `using Cxx`; Windows is a
deferred smoke-support target.

```julia
pkg> add https://github.com/terasakisatoshi/CxxFork.jl
pkg> build Cxx
```

Then:

```julia
julia> using Cxx
```

Building the native shim requires a working C/C++ toolchain and standard SDK or
developer tools for the host platform. On macOS, install Command Line Tools or
Xcode. During `Pkg.build()`, CxxFork records default C++ header paths and avoids
macOS SDK libc++ headers known to require Clang builtins unsupported by the
embedded Clang path.

## Contents

```@contents
Pages = [
    "api.md",
    "examples.md",
    "implementation.md",
    "repl.md",
]
Depth = 1
```
