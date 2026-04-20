using Test

include(joinpath(@__DIR__, "..", "..", "deps", "llvm_sources.jl"))
include(joinpath(@__DIR__, "..", "..", "deps", "build_libcxxffi.jl"))

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

@testset "build_env_paths" begin
    env = build_env_vars(
        prefix = raw"D:\a\CxxFork.jl\CxxFork.jl\deps\usr",
        base_julia_bin = raw"C:\hostedtoolcache\windows\julia\1.12.6\x64\bin",
        julia_prefix = raw"C:\hostedtoolcache\windows\julia\1.12.6\x64",
        llvm_ver = v"18.1.7",
        llvm_source_root = raw"D:\a\CxxFork.jl\CxxFork.jl\deps\usr\src\llvm-project-18.1.7",
        clang_artifact_dir = raw"C:\Users\runneradmin\.julia\artifacts\037bb3cc76618b33c395c8bea304d652d5590d1d",
        llvm_artifact_dir = raw"C:\Users\runneradmin\.julia\artifacts\a31fde35ae61c78ae4cd2f5ff2fed153f7297407",
        llvm_generated_include_dir = raw"C:\Users\runneradmin\.julia\artifacts\a31fde35ae61c78ae4cd2f5ff2fed153f7297407\include",
        compat_include_dir = raw"D:\a\CxxFork.jl\CxxFork.jl\deps\usr\include";
        windows = true,
    )

    @test env["PREFIX"] == "D:/a/CxxFork.jl/CxxFork.jl/deps/usr"
    @test env["BASE_JULIA_BIN"] == "C:/hostedtoolcache/windows/julia/1.12.6/x64/bin"
    @test env["JULIA_PREFIX"] == "C:/hostedtoolcache/windows/julia/1.12.6/x64"
    @test env["LLVM_SOURCE_ROOT"] == "D:/a/CxxFork.jl/CxxFork.jl/deps/usr/src/llvm-project-18.1.7"
    @test env["CLANG_ARTIFACT_DIR"] == "C:/Users/runneradmin/.julia/artifacts/037bb3cc76618b33c395c8bea304d652d5590d1d"
    @test env["LLVM_ARTIFACT_DIR"] == "C:/Users/runneradmin/.julia/artifacts/a31fde35ae61c78ae4cd2f5ff2fed153f7297407"
    @test env["LLVM_GENERATED_INCLUDE_DIR"] == "C:/Users/runneradmin/.julia/artifacts/a31fde35ae61c78ae4cd2f5ff2fed153f7297407/include"
    @test env["LLVM_COMPAT_INCLUDE_DIR"] == "D:/a/CxxFork.jl/CxxFork.jl/deps/usr/include"
end

@testset "select_clang_artifact_dir" begin
    @test select_clang_artifact_dir(
        clang_artifact_dir = raw"C:\Users\runneradmin\.julia\artifacts\037bb3cc76618b33c395c8bea304d652d5590d1d",
        llvm_artifact_dir = raw"C:\Users\runneradmin\.julia\artifacts\a31fde35ae61c78ae4cd2f5ff2fed153f7297407",
        windows = true,
    ) == raw"C:\Users\runneradmin\.julia\artifacts\a31fde35ae61c78ae4cd2f5ff2fed153f7297407"

    @test select_clang_artifact_dir(
        clang_artifact_dir = "/tmp/clang-artifact",
        llvm_artifact_dir = "/tmp/llvm-artifact",
        windows = false,
    ) == "/tmp/clang-artifact"
end
