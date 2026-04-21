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
    )
end

function build_testsuite(; include_extended::Bool = false)
    testsuite = core_testsuite()
    include_extended && merge!(testsuite, extended_testsuite())
    testsuite
end

function normalize_runner_args(args::AbstractVector{<:AbstractString})
    include_extended = any(==("extended"), args)
    passthrough_args = filter(!=("extended"), collect(args))
    return include_extended, passthrough_args
end

end
