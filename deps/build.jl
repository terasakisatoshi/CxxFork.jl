if "@stdlib" ∉ LOAD_PATH
    push!(LOAD_PATH, "@stdlib")
end

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
        llvm_source_root = build_info.llvm_source_root,
        clang_artifact_dir = build_info.clang_artifact_dir,
    )
end

function write_path_file(; base_julia_bin, julia_prefix, llvm_source_root, clang_artifact_dir)
    contents = """
const BASE_JULIA_BIN = $(sprint(show, base_julia_bin))
export BASE_JULIA_BIN

const JULIA_PREFIX = $(sprint(show, julia_prefix))
export JULIA_PREFIX

const LLVM_SOURCE_ROOT = $(sprint(show, llvm_source_root))
export LLVM_SOURCE_ROOT

const CLANG_ARTIFACT_DIR = $(sprint(show, clang_artifact_dir))
export CLANG_ARTIFACT_DIR

const IS_BINARYBUILD = true
export IS_BINARYBUILD
"""
    open(joinpath(DEPS_DIR, "path.jl"), "w") do io
        write(io, contents)
    end
end

main()
