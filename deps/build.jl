if "@stdlib" ∉ LOAD_PATH
    push!(LOAD_PATH, "@stdlib")
end

ENV["JULIA_PKG_PRECOMPILE_AUTO"] = "0"

include("build_libcxxffi.jl")
include("header_paths.jl")

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
        cxx_header_dirs = CxxHeaderPaths.default_cxx_header_dirs(),
    )
end

function write_path_file(; base_julia_bin, julia_prefix, base_julia_src, llvm_source_root, clang_artifact_dir, cxx_header_dirs)
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
