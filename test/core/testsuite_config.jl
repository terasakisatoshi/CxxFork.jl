using Test

include(joinpath(@__DIR__, "..", "testsuite_config.jl"))
using .TestsuiteConfig

@testset "normalize_runner_args" begin
    include_extended, include_exceptions, passthrough_args = TestsuiteConfig.normalize_runner_args(["extended", "exceptions", "--jobs=1"])

    @test include_extended === true
    @test include_exceptions === true
    @test passthrough_args == ["--jobs=1"]
end

@testset "build_testsuite" begin
    core_suite = TestsuiteConfig.build_testsuite()
    extended_suite = TestsuiteConfig.build_testsuite(include_extended = true)
    exceptions_suite = TestsuiteConfig.build_testsuite(include_exceptions = true)

    @test haskey(core_suite, "core/simple_cxx")
    @test !haskey(core_suite, "optin/exceptions_basic")
    @test !haskey(core_suite, "extended/ctest")

    @test haskey(extended_suite, "core/simple_cxx")
    @test haskey(extended_suite, "extended/ctest")
    @test !haskey(extended_suite, "optin/exceptions_basic")

    @test haskey(exceptions_suite, "optin/exceptions_basic")
end
