using Test

include(joinpath(@__DIR__, "..", "..", "deps", "llvm_sources.jl"))

@testset "llvm_sources_paths" begin
    @test tar_compatible_path(raw"D:\a\CxxFork.jl\CxxFork.jl\deps\usr\src\llvm-project-18.1.7.src.tar.xz"; windows = true) ==
          "/d/a/CxxFork.jl/CxxFork.jl/deps/usr/src/llvm-project-18.1.7.src.tar.xz"
    @test tar_compatible_path(raw"D:\a\CxxFork.jl\CxxFork.jl\deps\usr\src"; windows = true) ==
          "/d/a/CxxFork.jl/CxxFork.jl/deps/usr/src"
    @test tar_compatible_path("/tmp/llvm-project-18.1.7.src.tar.xz"; windows = false) ==
          "/tmp/llvm-project-18.1.7.src.tar.xz"
end
