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
