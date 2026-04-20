using ParallelTestRunner
using Cxx

testsuite = Dict(
    "core/llvm_sources_paths" => :(include(joinpath(@__DIR__, "core", "llvm_sources_paths.jl"))),
    "core/smoke_load" => :(include(joinpath(@__DIR__, "core", "smoke_load.jl"))),
    "core/simple_cxx" => :(include(joinpath(@__DIR__, "core", "simple_cxx.jl"))),
)

runtests(Cxx, ARGS; testsuite)
