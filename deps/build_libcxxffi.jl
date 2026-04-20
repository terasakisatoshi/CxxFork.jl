if "@stdlib" ∉ LOAD_PATH
    push!(LOAD_PATH, "@stdlib")
end

using Pkg

include("llvm_sources.jl")

const BUILD_ENV_DIR = joinpath(@__DIR__, "build_env")

function build_libcxxffi(; prefix::AbstractString,
                         base_julia_bin::AbstractString,
                         julia_prefix::AbstractString,
                         llvm_ver::VersionNumber = Base.libllvm_version)
    prefix = normpath(prefix)
    base_julia_bin = normpath(base_julia_bin)
    julia_prefix = normpath(julia_prefix)

    llvm_source_root = ensure_llvm_sources!(llvm_ver)
    artifacts = ensure_build_artifacts!(llvm_ver)
    compat_include_dir = stage_compat_headers!(prefix)
    stage_clang_builtin_headers!(prefix, artifacts.clang_artifact_dir, llvm_ver)
    stage_legacy_source_layout!(prefix, llvm_source_root, artifacts, llvm_ver)

    mkpath(prefix)
    env = build_env_vars(
        prefix = prefix,
        base_julia_bin = base_julia_bin,
        julia_prefix = julia_prefix,
        llvm_ver = llvm_ver,
        llvm_source_root = llvm_source_root,
        clang_artifact_dir = artifacts.clang_artifact_dir,
        llvm_artifact_dir = artifacts.llvm_artifact_dir,
        llvm_generated_include_dir = artifacts.llvm_generated_include_dir,
        compat_include_dir = compat_include_dir,
    )

    make = Sys.isbsd() && !Sys.isapple() ? `gmake` : `make`
    withenv((key => value for (key, value) in env)...) do
        run(`$make -f BuildBootstrap.Makefile all -j$(max(Sys.CPU_THREADS, 1))`)
    end

    return (
        llvm_source_root = llvm_source_root,
        clang_artifact_dir = artifacts.clang_artifact_dir,
        llvm_artifact_dir = artifacts.llvm_artifact_dir,
    )
end

function stage_clang_builtin_headers!(prefix::AbstractString,
                                      clang_artifact_dir::AbstractString,
                                      llvm_ver::VersionNumber)
    clang_root = joinpath(clang_artifact_dir, "lib", "clang")
    isdir(clang_root) || return nothing

    versions = sort(filter(entry -> isdir(joinpath(clang_root, entry, "include")), readdir(clang_root)))
    isempty(versions) && return nothing

    source_dir = joinpath(clang_root, last(versions), "include")
    dest_dir = joinpath(prefix, "build", "clang-$(llvm_ver)", "lib", "clang", string(llvm_ver), "include")
    mkpath(dirname(dest_dir))

    if ispath(dest_dir)
        rm(dest_dir; force = true, recursive = true)
    end
    symlink(source_dir, dest_dir)
    return dest_dir
end

function make_compatible_path(path::AbstractString; windows::Bool = Sys.iswindows())
    normalized = normpath(path)
    windows || return normalized
    return replace(normalized, '\\' => '/')
end

function build_env_vars(; prefix::AbstractString,
                        base_julia_bin::AbstractString,
                        julia_prefix::AbstractString,
                        llvm_ver::VersionNumber,
                        llvm_source_root::AbstractString,
                        clang_artifact_dir::AbstractString,
                        llvm_artifact_dir::AbstractString,
                        llvm_generated_include_dir::AbstractString,
                        compat_include_dir::AbstractString,
                        windows::Bool = Sys.iswindows())
    return Dict(
        "PREFIX" => make_compatible_path(prefix; windows),
        "BASE_JULIA_BIN" => make_compatible_path(base_julia_bin; windows),
        "JULIA_PREFIX" => make_compatible_path(julia_prefix; windows),
        "LLVM_VER" => string(llvm_ver),
        "LLVM_SOURCE_ROOT" => make_compatible_path(llvm_source_root; windows),
        "CLANG_ARTIFACT_DIR" => make_compatible_path(clang_artifact_dir; windows),
        "LLVM_ARTIFACT_DIR" => make_compatible_path(llvm_artifact_dir; windows),
        "LLVM_GENERATED_INCLUDE_DIR" => make_compatible_path(llvm_generated_include_dir; windows),
        "LLVM_COMPAT_INCLUDE_DIR" => make_compatible_path(compat_include_dir; windows),
    )
end

function stage_legacy_source_layout!(prefix::AbstractString,
                                     llvm_source_root::AbstractString,
                                     artifacts,
                                     llvm_ver::VersionNumber)
    src_root = dirname(llvm_source_root)
    link_if_missing(joinpath(src_root, "clang-$(llvm_ver)"), joinpath(llvm_source_root, "clang"))
    link_if_missing(joinpath(src_root, "llvm-$(llvm_ver)"), joinpath(llvm_source_root, "llvm"))

    build_root = joinpath(prefix, "build")
    link_if_missing(joinpath(build_root, "clang-$(llvm_ver)", "include"), joinpath(artifacts.clang_artifact_dir, "include"))
    link_if_missing(joinpath(build_root, "llvm-$(llvm_ver)", "include"), artifacts.llvm_generated_include_dir)
    return nothing
end

function link_if_missing(dest::AbstractString, src::AbstractString)
    mkpath(dirname(dest))
    if ispath(dest)
        rm(dest; force = true, recursive = true)
    end
    symlink(src, dest)
    return dest
end

function ensure_build_artifacts!(llvm_ver::VersionNumber)
    mkpath(BUILD_ENV_DIR)
    Pkg.activate(BUILD_ENV_DIR; shared = false)
    Pkg.add(name = "Clang_jll", version = string(llvm_ver))
    Pkg.add(name = "LLVM_full_jll", version = string(llvm_ver))

    Base.invokelatest(() -> Base.eval(Main, :(using Clang_jll)))
    Base.invokelatest(() -> Base.eval(Main, :(using LLVM_full_jll)))
    clang_jll = Base.invokelatest(() -> getfield(Main, :Clang_jll))
    llvm_full_jll = Base.invokelatest(() -> getfield(Main, :LLVM_full_jll))
    return (
        clang_artifact_dir = normpath(Base.invokelatest(() -> getproperty(clang_jll, :artifact_dir))),
        llvm_artifact_dir = normpath(Base.invokelatest(() -> getproperty(llvm_full_jll, :artifact_dir))),
        llvm_generated_include_dir = normpath(joinpath(Base.invokelatest(() -> getproperty(llvm_full_jll, :artifact_dir)), "include")),
    )
end

function stage_compat_headers!(prefix::AbstractString)
    compat_root = joinpath(prefix, "include")
    write_if_changed(
        joinpath(compat_root, "clang", "Basic", "VirtualFileSystem.h"),
        clang_virtual_filesystem_header(),
    )
    write_if_changed(
        joinpath(compat_root, "clang", "Sema", "PrettyDeclStackTrace.h"),
        clang_pretty_decl_stack_trace_header(),
    )
    write_if_changed(
        joinpath(compat_root, "clang", "Frontend", "CodeGenOptions.h"),
        clang_frontend_codegen_options_header(),
    )
    write_if_changed(
        joinpath(compat_root, "llvm", "Support", "Host.h"),
        llvm_host_header(),
    )
    return compat_root
end

function write_if_changed(path::AbstractString, content::AbstractString)
    mkpath(dirname(path))
    if isfile(path) && read(path, String) == content
        return path
    end
    open(path, "w") do io
        write(io, content)
    end
    return path
end

function clang_virtual_filesystem_header()
    return """
/* Auto-generated by deps/build_libcxxffi.jl */
#pragma once

#include "llvm/Support/VirtualFileSystem.h"

namespace clang {
namespace vfs = llvm::vfs;
}
"""
end

function clang_pretty_decl_stack_trace_header()
    return """
/* Auto-generated by deps/build_libcxxffi.jl */
#pragma once

#include "clang/AST/PrettyDeclStackTrace.h"
"""
end

function clang_frontend_codegen_options_header()
    return """
/* Auto-generated by deps/build_libcxxffi.jl */
#pragma once

#include "clang/Basic/CodeGenOptions.h"
"""
end

function llvm_host_header()
    return """
/* Auto-generated by deps/build_libcxxffi.jl */
#pragma once

#include "llvm/TargetParser/Host.h"
"""
end
