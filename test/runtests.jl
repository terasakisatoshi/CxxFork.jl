using ParallelTestRunner
using Cxx

testsuite = Dict(
    "core/smoke_load" => :(include(joinpath(@__DIR__, "core", "smoke_load.jl"))),
)

runtests(Cxx, ARGS; testsuite)
