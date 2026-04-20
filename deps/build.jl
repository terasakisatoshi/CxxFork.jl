if "@stdlib" ∉ LOAD_PATH
    push!(LOAD_PATH, "@stdlib")
end

ENV["JULIA_PKG_PRECOMPILE_AUTO"] = "0"

include("build_libcxxffi.jl")

const DEPS_DIR = @__DIR__

function main()
    base_julia_bin = normpath(get(ENV, "BASE_JULIA_BIN", Sys.BINDIR))
    julia_prefix = normpath(get(ENV, "JULIA_PREFIX", joinpath(base_julia_bin, "..")))
    prefix = joinpath(DEPS_DIR, "usr")

    build_info = build_libcxxffi(;
        prefix,
        base_julia_bin,
        julia_prefix,
        llvm_ver = Base.libllvm_version,
    )

    write_path_file(;
        base_julia_bin,
        julia_prefix,
        base_julia_src = julia_prefix,
        llvm_source_root = build_info.llvm_source_root,
        clang_artifact_dir = build_info.clang_artifact_dir,
        llvm_artifact_dir = build_info.llvm_artifact_dir,
        cxx_header_dirs = default_cxx_header_dirs(),
    )
end

function default_cxx_header_dirs()
    dirs = String[]
    if Sys.isapple()
        clt_sdk_root = "/Library/Developer/CommandLineTools/SDKs"
        clt_sdks = isdir(clt_sdk_root) ? sort(filter(name -> startswith(name, "MacOSX"), readdir(clt_sdk_root))) : String[]
        xcode_path = try
            strip(read(`xcode-select --print-path`, String))
        catch
            ""
        end
        sdk_path = try
            strip(read(`xcrun --sdk macosx --show-sdk-path`, String))
        catch
            ""
        end

        candidates = String[]
        if !isempty(clt_sdks)
            clt_sdk_path = joinpath(clt_sdk_root, first(clt_sdks))
            append!(candidates, [
                joinpath(clt_sdk_path, "usr", "include", "c++", "v1"),
                joinpath(clt_sdk_path, "usr", "include"),
            ])
        elseif !isempty(sdk_path)
            append!(candidates, [
                joinpath(sdk_path, "usr", "include", "c++", "v1"),
                joinpath(sdk_path, "usr", "include"),
            ])
        end
        if !isempty(xcode_path)
            toolchain = occursin("Xcode", xcode_path) ?
                joinpath(xcode_path, "Toolchains", "XcodeDefault.xctoolchain") :
                xcode_path
            append!(candidates, [
                joinpath(toolchain, "usr", "include", "c++", "v1"),
                joinpath(toolchain, "usr", "include"),
            ])
        end

        for candidate in candidates
            isdir(candidate) && candidate ∉ dirs && push!(dirs, candidate)
        end
    end
    return dirs
end

function write_path_file(; base_julia_bin, julia_prefix, base_julia_src, llvm_source_root, clang_artifact_dir, llvm_artifact_dir, cxx_header_dirs)
    contents = """
const BASE_JULIA_BIN = $(sprint(show, base_julia_bin))
export BASE_JULIA_BIN

const JULIA_PREFIX = $(sprint(show, julia_prefix))
export JULIA_PREFIX

const BASE_JULIA_SRC = $(sprint(show, base_julia_src))
export BASE_JULIA_SRC

const LLVM_SOURCE_ROOT = $(sprint(show, llvm_source_root))
export LLVM_SOURCE_ROOT

const CLANG_ARTIFACT_DIR = $(sprint(show, clang_artifact_dir))
export CLANG_ARTIFACT_DIR

const LLVM_ARTIFACT_DIR = $(sprint(show, llvm_artifact_dir))
export LLVM_ARTIFACT_DIR

const DEFAULT_CXXJL_HEADER_DIRS = $(sprint(show, cxx_header_dirs))
export DEFAULT_CXXJL_HEADER_DIRS

if Sys.isapple() && !isempty(DEFAULT_CXXJL_HEADER_DIRS) && !haskey(ENV, "CXXJL_HEADER_DIRS")
    ENV["CXXJL_HEADER_DIRS"] = join(DEFAULT_CXXJL_HEADER_DIRS, ":")
    ENV["CXXJL_NOSTDCXX"] = get(ENV, "CXXJL_NOSTDCXX", "1")
end

const IS_BINARYBUILD = true
export IS_BINARYBUILD
"""
    open(joinpath(DEPS_DIR, "path.jl"), "w") do io
        write(io, contents)
    end
end

main()
