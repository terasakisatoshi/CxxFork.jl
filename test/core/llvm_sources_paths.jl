using Test

include(joinpath(@__DIR__, "..", "..", "deps", "llvm_sources.jl"))

@testset "llvm_sources_paths" begin
    @test tar_compatible_path(raw"D:\a\CxxFork.jl\CxxFork.jl\deps\usr\src\llvm-project-18.1.7.src.tar.xz"; windows = true) ==
          "/d/a/CxxFork.jl/CxxFork.jl/deps/usr/src/llvm-project-18.1.7.src.tar.xz"
    @test tar_compatible_path(raw"D:\a\CxxFork.jl\CxxFork.jl\deps\usr\src"; windows = true) ==
          "/d/a/CxxFork.jl/CxxFork.jl/deps/usr/src"
    @test tar_compatible_path("/tmp/llvm-project-18.1.7.src.tar.xz"; windows = false) ==
          "/tmp/llvm-project-18.1.7.src.tar.xz"

    members = llvm_source_archive_members(v"18.1.7")
    @test members == [
        "llvm-project-18.1.7.src/llvm/include",
        "llvm-project-18.1.7.src/clang/include",
        "llvm-project-18.1.7.src/clang/lib",
    ]

    cmd = tar_extract_cmd("/tmp/llvm-project-18.1.7.src.tar.xz", "/tmp"; windows = false)
    @test collect(cmd) == [
        "tar",
        "-xf",
        "/tmp/llvm-project-18.1.7.src.tar.xz",
        "-C",
        "/tmp",
        "llvm-project-18.1.7.src/llvm/include",
        "llvm-project-18.1.7.src/clang/include",
        "llvm-project-18.1.7.src/clang/lib",
    ]

    windows_cmd = tar_extract_cmd(
        raw"D:\a\CxxFork.jl\CxxFork.jl\deps\usr\src\llvm-project-18.1.7.src.tar.xz",
        raw"D:\a\CxxFork.jl\CxxFork.jl\deps\usr\src";
        windows = true,
    )
    @test collect(windows_cmd) == [
        "tar",
        "-xf",
        "/d/a/CxxFork.jl/CxxFork.jl/deps/usr/src/llvm-project-18.1.7.src.tar.xz",
        "-C",
        "/d/a/CxxFork.jl/CxxFork.jl/deps/usr/src",
        "llvm-project-18.1.7.src/llvm/include",
        "llvm-project-18.1.7.src/clang/include",
        "llvm-project-18.1.7.src/clang/lib",
    ]
end
