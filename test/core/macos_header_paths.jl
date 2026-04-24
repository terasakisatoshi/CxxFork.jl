using Test

include(joinpath(@__DIR__, "..", "..", "deps", "header_paths.jl"))

function write_libcxx_probe(root::AbstractString, body::AbstractString)
    probe = joinpath(root, "usr", "include", "c++", "v1", "__bit", "countr.h")
    mkpath(dirname(probe))
    write(probe, body)
end

@testset "macos_header_paths" begin
    mktempdir() do sdk_root
        sdk15 = joinpath(sdk_root, "MacOSX15.4.sdk")
        sdk26 = joinpath(sdk_root, "MacOSX26.4.sdk")

        write_libcxx_probe(sdk15, """
        #if __has_builtin(__builtin_ctzg)
        inline int guarded(int x) { return __builtin_ctzg(x, 32); }
        #else
        inline int guarded(int x) { return x; }
        #endif
        """)
        write_libcxx_probe(sdk26, "inline int bad(int x) { return __builtin_ctzg(x, 32); }\n")
        symlink("MacOSX26.4.sdk", joinpath(sdk_root, "MacOSX.sdk"))

        selected = CxxHeaderPaths.macos_sdk_header_candidates(;
            clt_sdk_root = sdk_root,
            active_sdk_path = joinpath(sdk_root, "MacOSX.sdk"),
            xcode_toolchain_path = "",
        )

        @test joinpath(realpath(sdk15), "usr", "include", "c++", "v1") in selected
        @test joinpath(realpath(sdk15), "usr", "include") in selected
        @test joinpath(realpath(sdk26), "usr", "include", "c++", "v1") ∉ selected
        @test joinpath(realpath(joinpath(sdk_root, "MacOSX.sdk")), "usr", "include", "c++", "v1") ∉ selected
    end
end
