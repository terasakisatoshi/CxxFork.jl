# C++ Exception Opt-In Lane Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated opt-in exception test lane for `macOS arm64 + Julia 1.12` without changing the baseline or ordinary extended support contract.

**Architecture:** Keep the existing exception callback machinery in `src/exceptions.jl` and `src/initialization.jl` unchanged. Extend the test runner so it can select a dedicated `exceptions` lane, add one self-contained test file that requires `CXX_ENABLE_EXCEPTIONS=1` before `using Cxx`, then document and CI-wire that lane separately from `extended`.

**Tech Stack:** Julia 1.12, Cxx.jl runtime init hooks, ParallelTestRunner.jl, GitHub Actions

---

## File Map

- `test/testsuite_config.jl`
  - Add a dedicated exception-only testsuite map.
  - Extend runner argument parsing to understand `exceptions`.
- `test/runtests.jl`
  - Pass the new lane-selection boolean into `build_testsuite`.
- `test/core/testsuite_config.jl`
  - Lock down the runner contract for the new `exceptions` lane.
- `test/optin/exceptions_basic.jl`
  - New self-contained exception opt-in suite covering built-in throw, user-defined `@exception`, and `std::length_error`.
- `README.md`
  - Document the new opt-in lane and its supported scope.
- `.github/workflows/ci.yml`
  - Add a dedicated macOS arm64 exceptions job with `CXX_ENABLE_EXCEPTIONS=1`.

### Task 1: Add Runner Plumbing For A Dedicated `exceptions` Lane

**Files:**
- Modify: `test/testsuite_config.jl`
- Modify: `test/runtests.jl`
- Modify: `test/core/testsuite_config.jl`
- Test: `test/core/testsuite_config.jl`

- [ ] **Step 1: Write the failing runner-contract test**

Update `test/core/testsuite_config.jl` so it expects a second lane selector and a dedicated suite entry:

```julia
using Test

include(joinpath(@__DIR__, "..", "testsuite_config.jl"))
using .TestsuiteConfig

@testset "normalize_runner_args" begin
    include_extended, include_exceptions, passthrough_args =
        TestsuiteConfig.normalize_runner_args(["extended", "exceptions", "--jobs=1"])

    @test include_extended === true
    @test include_exceptions === true
    @test passthrough_args == ["--jobs=1"]
end

@testset "build_testsuite" begin
    core_suite = TestsuiteConfig.build_testsuite()
    extended_suite = TestsuiteConfig.build_testsuite(include_extended = true)
    exception_suite = TestsuiteConfig.build_testsuite(include_exceptions = true)

    @test haskey(core_suite, "core/simple_cxx")
    @test !haskey(core_suite, "optin/exceptions_basic")
    @test !haskey(extended_suite, "optin/exceptions_basic")
    @test haskey(exception_suite, "optin/exceptions_basic")
end
```

- [ ] **Step 2: Run the runner-contract test to verify it fails**

Run:

```bash
julia --project=. test/core/testsuite_config.jl
```

Expected: FAIL because `normalize_runner_args` still returns two values and `build_testsuite` does not yet accept `include_exceptions`.

- [ ] **Step 3: Write the minimal runner changes**

Update `test/testsuite_config.jl` and `test/runtests.jl` like this:

```julia
module TestsuiteConfig

function core_testsuite()
    Dict(
        "core/bootstrap_portability" => :(include(joinpath(@__DIR__, "core", "bootstrap_portability.jl"))),
        "core/llvm_sources_paths" => :(include(joinpath(@__DIR__, "core", "llvm_sources_paths.jl"))),
        "core/smoke_load" => :(include(joinpath(@__DIR__, "core", "smoke_load.jl"))),
        "core/simple_cxx" => :(include(joinpath(@__DIR__, "core", "simple_cxx.jl"))),
        "core/testsuite_config" => :(include(joinpath(@__DIR__, "core", "testsuite_config.jl"))),
    )
end

function extended_testsuite()
    Dict(
        "extended/ctest" => :(include(joinpath(@__DIR__, "ctest.jl"))),
        "extended/std_map_basic" => :(include(joinpath(@__DIR__, "extended", "std_map_basic.jl"))),
        "extended/std_string" => :(include(joinpath(@__DIR__, "extended", "std_string.jl"))),
        "extended/std_vector_basic" => :(include(joinpath(@__DIR__, "extended", "std_vector_basic.jl"))),
        "extended/std_vector_wrappers" => :(include(joinpath(@__DIR__, "extended", "std_vector_wrappers.jl"))),
    )
end

function exception_testsuite()
    Dict(
        "optin/exceptions_basic" => :(include(joinpath(@__DIR__, "optin", "exceptions_basic.jl"))),
    )
end

function build_testsuite(; include_extended::Bool = false, include_exceptions::Bool = false)
    testsuite = core_testsuite()
    include_extended && merge!(testsuite, extended_testsuite())
    include_exceptions && merge!(testsuite, exception_testsuite())
    testsuite
end

function normalize_runner_args(args::AbstractVector{<:AbstractString})
    include_extended = any(==("extended"), args)
    include_exceptions = any(==("exceptions"), args)
    passthrough_args = filter(arg -> arg != "extended" && arg != "exceptions", collect(args))
    return include_extended, include_exceptions, passthrough_args
end

end
```

```julia
using ParallelTestRunner
using Cxx

include(joinpath(@__DIR__, "testsuite_config.jl"))
using .TestsuiteConfig

include_extended, include_exceptions, passthrough_args =
    TestsuiteConfig.normalize_runner_args(ARGS)
testsuite = TestsuiteConfig.build_testsuite(
    include_extended = include_extended,
    include_exceptions = include_exceptions,
)

runtests(Cxx, passthrough_args; testsuite)
```

- [ ] **Step 4: Run the runner-contract test to verify it passes**

Run:

```bash
julia --project=. test/core/testsuite_config.jl
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/testsuite_config.jl test/runtests.jl test/core/testsuite_config.jl
git commit -m "test: add exception opt-in test lane plumbing"
```

### Task 2: Extract A Self-Contained Exception Opt-In Suite

**Files:**
- Create: `test/optin/exceptions_basic.jl`
- Test: `test/optin/exceptions_basic.jl`
- Test: `test/testsuite_config.jl`

- [ ] **Step 1: Write the dedicated exception suite**

Create `test/optin/exceptions_basic.jl` with the supported opt-in scenarios and an explicit environment requirement:

```julia
using Cxx
using Test

Cxx.ENABLE_CXX_EXCEPTIONS || error(
    "optin/exceptions_basic requires CXX_ENABLE_EXCEPTIONS=1 before Julia starts",
)

@testset "exception opt-in lane" begin
    @testset "builtin throw" begin
        try
            icxx" throw 20; "
            error("expected builtin C++ exception translation")
        catch err
            @test err isa CxxException
            @test sprint(showerror, err) == "20"
        end
    end

    cxx"""
    class plan_exception : public std::exception
    {
    public:
        int x;
        plan_exception(int x) : x(x) {};
    };
    """

    import Base: showerror
    @exception function showerror(io::IO, e::rcpp"plan_exception")
        print(io, icxx"$e.x;")
    end

    @testset "@exception formatting" begin
        try
            icxx" throw plan_exception(5); "
            error("expected user-defined C++ exception translation")
        catch err
            @test sprint(showerror, err) == "5"
        end
    end

    @testset "std::length_error" begin
        v = icxx"std::vector<int>{1, 2, 3};"
        try
            icxx"$v.resize($v.max_size() + 1);"
            error("expected std::length_error translation")
        catch err
            @test err isa CxxException{:St12length_error}
            @test startswith(sprint(showerror, err), "vector")
        end
    end
end
```

- [ ] **Step 2: Run the dedicated lane without the environment variable and verify it fails clearly**

Run:

```bash
julia --project=. -e 'using Pkg; Pkg.test(test_args=["exceptions","--jobs=1"])'
```

Expected: FAIL with the explicit `CXX_ENABLE_EXCEPTIONS=1 before Julia starts` message.

- [ ] **Step 3: Run the dedicated lane with the environment variable and verify it passes**

Run:

```bash
CXX_ENABLE_EXCEPTIONS=1 julia --project=. -e 'using Pkg; Pkg.test(test_args=["exceptions","--jobs=1"])'
```

Expected: PASS on `macOS arm64 + Julia 1.12`.

- [ ] **Step 4: Commit**

```bash
git add test/optin/exceptions_basic.jl
git commit -m "test: add exception opt-in coverage"
```

### Task 3: Document And CI-Wire The Exception Opt-In Lane

**Files:**
- Modify: `README.md`
- Modify: `.github/workflows/ci.yml`
- Test: baseline, extended, and exceptions commands

- [ ] **Step 1: Update README to document the separate exception lane**

Revise the platform-notes and verification sections so they distinguish baseline, extended, and exception opt-in validation:

```md
- `CXX_ENABLE_EXCEPTIONS=1` enables exception callback setup for the dedicated opt-in exception lane
```

```md
To run the exception opt-in lane:

    CXX_ENABLE_EXCEPTIONS=1 julia --project=. -e 'using Pkg; Pkg.test(test_args=["exceptions","--jobs=1"])'
```

```md
- `optin/exceptions_basic` for verified built-in throw translation, `@exception` formatting, and `std::length_error` formatting on `macOS arm64 + Julia 1.12`
```

- [ ] **Step 2: Add a dedicated CI job**

Extend `.github/workflows/ci.yml` with a separate job rather than folding exception coverage into `macos-arm64-extended`:

```yaml
  macos-arm64-exceptions:
    name: macOS arm64 exceptions
    runs-on: macos-14
    env:
      CXX_ENABLE_EXCEPTIONS: "1"
    steps:
      - uses: actions/checkout@v4
      - uses: julia-actions/setup-julia@v2
        with:
          version: "1.12"
      - uses: julia-actions/cache@v2
      - name: Build
        run: julia --project=. -e 'using Pkg; Pkg.build()'
      - name: Exception Opt-In Test
        run: julia --project=. -e 'using Pkg; Pkg.test(test_args=["exceptions","--jobs=1"])'
```

- [ ] **Step 3: Run the full verification set**

Run:

```bash
env JULIA_PKG_PRECOMPILE_AUTO=0 julia --project=. -e 'using Pkg; Pkg.build()'
julia --project=. --compiled-modules=no -e 'using Cxx; println("using Cxx ok")'
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. -e 'using Pkg; Pkg.test(test_args=["extended","--jobs=1"])'
CXX_ENABLE_EXCEPTIONS=1 julia --project=. -e 'using Pkg; Pkg.test(test_args=["exceptions","--jobs=1"])'
```

Expected:

- baseline import PASS
- baseline `Pkg.test()` PASS
- extended lane PASS
- exception opt-in lane PASS

- [ ] **Step 4: Commit**

```bash
git add README.md .github/workflows/ci.yml
git commit -m "docs: wire exception opt-in lane"
```
