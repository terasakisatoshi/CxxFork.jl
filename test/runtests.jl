using ParallelTestRunner
using Cxx

include(joinpath(@__DIR__, "testsuite_config.jl"))
using .TestsuiteConfig

include_extended, include_exceptions, passthrough_args = TestsuiteConfig.normalize_runner_args(ARGS)
testsuite = TestsuiteConfig.build_testsuite(
    include_extended = include_extended,
    include_exceptions = include_exceptions,
)

runtests(Cxx, passthrough_args; testsuite)
