# String-Key std::map Iteration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `std::map<std::string, std::string>` iteration stable enough to convert iterated keys and values to Julia `String` in the extended verification lane without broadening general `const std::string` support.

**Architecture:** Keep the fix local to `src/std.jl` by normalizing `const std::string` values returned from `std::map` iteration into supported `std::string` copies before Julia-side `String` conversion happens. Preserve the existing generic `std::map` iteration path for non-string maps, and extend the existing `extended/std_map_basic` suite to lock the behavior down.

**Tech Stack:** Julia 1.12, Cxx.jl `icxx`/`cxxt` wrappers, ParallelTestRunner, GitHub issue `#20`

---

### Task 1: Add the failing string-key map iteration test and implement the local normalization

**Files:**
- Modify: `test/extended/std_map_basic.jl`
- Modify: `src/std.jl`
- Test: `test/extended/std_map_basic.jl`

- [ ] **Step 1: Write the failing test**

Replace the current test body in `test/extended/std_map_basic.jl` with the following so the string-key path is exercised before any implementation change:

```julia
using Cxx
using Test

cxx"""
#include <map>
#include <string>

using Map17 = std::map<std::string, std::string>;

Map17 get_map17() {
    return Map17({{"hello", "world"}, {"everything", "awesome"}});
}
"""

@testset "std_map basic" begin
    m = @cxx get_map17()
    @test length(m) == 2
    @test Dict(String(k) => String(v) for (k, v) in m) ==
        Dict("everything" => "awesome", "hello" => "world")

    int_map = icxx"std::map<int32_t, int32_t> m; m.emplace(1, 10); m.emplace(2, 20); m;"
    @test length(int_map) == 2
    @test collect(int_map) == Any[Int32(1) => Int32(10), Int32(2) => Int32(20)]
end
```

- [ ] **Step 2: Run the test to verify it fails for the expected reason**

Run:

```bash
julia --project=. test/extended/std_map_basic.jl
```

Expected:
- `std_map basic` fails
- the failure is on `Dict(String(k) => String(v) ...)`
- the error is a `MethodError` for `String(::const std::string)` or a closely related unstable `const std::string` map iteration failure

- [ ] **Step 3: Write the minimal implementation in `src/std.jl`**

Update `src/std.jl` so `std::map` iteration copies only `const std::string` values into supported `std::string` values before returning them to Julia:

```julia
const StdString = cxxt"std::string"
const StdStringR = cxxt"std::string&"
const StdStringConst = cxxt"const std::string"
const StdStringConstR = cxxt"const std::string&"
const StdVector{T} = Union{cxxt"std::vector<$T>",cxxt"std::vector<$T>&"}
const StdMap{K,V} = cxxt"std::map<$K,$V>"

function _copy_std_string(str::Union{StdString,StdStringR,StdStringConst,StdStringConstR})
    ensure_std_string_header!()
    icxx"std::string s($str); return s;"
end

_normalize_std_map_value(x) = x
_normalize_std_map_value(x::Union{StdStringConst,StdStringConstR}) = _copy_std_string(x)

function Base.iterate(map::GenericStdMap, i = icxx"$map.begin();")
    if icxx"return $i == $map.end();"
        return nothing
    end
    key = _normalize_std_map_value(icxx"return $i->first;")
    val = _normalize_std_map_value(icxx"return $i->second;")
    icxx"++$i;"
    (key => val, i)
end
```

Do not change `String(::const std::string)` or `convert(String, ::const std::string&)` here. Keep the fix local to map iteration.

- [ ] **Step 4: Run the targeted test to verify it passes**

Run:

```bash
julia --project=. test/extended/std_map_basic.jl
```

Expected:
- `Test Summary: | Pass  Total`
- `std_map basic |    4      4`
- process exits `0`

- [ ] **Step 5: Commit the code and test change**

Run:

```bash
git add src/std.jl test/extended/std_map_basic.jl
git commit -m "test: stabilize string-key std::map iteration"
```

Expected:
- one commit containing only the local `std::map` normalization and the extended test update

### Task 2: Update documentation and run the full verification lane

**Files:**
- Modify: `README.md`
- Test: `test/extended/std_map_basic.jl`
- Test: repository verification commands from `AGENTS.md`

- [ ] **Step 1: Update README wording to reflect the new support**

Replace the current `extended/std_map_basic` bullet in `README.md` with the supported claim after Task 1:

```md
- `extended/std_map_basic` for verified `std::map<std::string, std::string>` length and Julia `String` iteration, plus `std::map<int32_t, int32_t>` length/iteration coverage
```

- [ ] **Step 2: Run the required full verification commands**

Run:

```bash
env JULIA_PKG_PRECOMPILE_AUTO=0 julia --project=. -e 'using Pkg; Pkg.build()'
julia --project=. --compiled-modules=no -e 'using Cxx; println("using Cxx ok")'
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. -e 'using Pkg; Pkg.test(test_args=["extended","--jobs=1"])'
```

Expected:
- `Pkg.build()` exits `0`
- `using Cxx ok`
- baseline `Pkg.test()` passes
- extended lane passes with `extended/std_map_basic` included

- [ ] **Step 3: Commit the README update after verification**

Run:

```bash
git add README.md
git commit -m "docs: mark string-key std::map iteration verified"
```

Expected:
- a docs-only follow-up commit on top of the code/test commit

- [ ] **Step 4: Confirm the branch is clean**

Run:

```bash
git status --short
```

Expected:
- no output
