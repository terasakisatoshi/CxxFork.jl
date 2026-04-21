using ParallelTestRunner
using Cxx

include(joinpath(@__DIR__, "testsuite_config.jl"))
using .TestsuiteConfig

include_extended, passthrough_args = TestsuiteConfig.normalize_runner_args(ARGS)
testsuite = TestsuiteConfig.build_testsuite(include_extended = include_extended)

runtests(Cxx, passthrough_args; testsuite)
