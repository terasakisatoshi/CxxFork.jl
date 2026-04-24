module CxxHeaderPaths

export default_cxx_header_dirs, macos_sdk_header_candidates

const UNSUPPORTED_LIBCXX_BUILTINS = ("__builtin_ctzg", "__builtin_clzg")
const LIBCXX_PROBE_FILES = (
    joinpath("__bit", "countr.h"),
    joinpath("__bit", "countl.h"),
    joinpath("__charconv", "traits.h"),
)

function unique_existing_dirs(paths)
    dirs = String[]
    seen = Set{String}()
    for path in paths
        isempty(path) && continue
        isdir(path) || continue
        real = realpath(path)
        real in seen && continue
        push!(seen, real)
        push!(dirs, real)
    end
    return dirs
end

function macos_sdk_version(path::AbstractString)
    name = basename(realpath(path))
    matched = match(r"^MacOSX(\d+(?:\.\d+)*)\.sdk$", name)
    matched === nothing && return v"0"
    return VersionNumber(matched.captures[1])
end

function has_unsupported_libcxx_builtins(include_dir::AbstractString)
    for relative in LIBCXX_PROBE_FILES
        path = joinpath(include_dir, relative)
        isfile(path) || continue
        contents = read(path, String)
        for builtin in UNSUPPORTED_LIBCXX_BUILTINS
            occursin(builtin, contents) || continue
            occursin("__has_builtin($builtin)", contents) || return true
        end
    end
    return false
end

function compatible_macos_sdk_paths(; clt_sdk_root::AbstractString, active_sdk_path::AbstractString)
    candidates = String[]
    if isdir(clt_sdk_root)
        for name in readdir(clt_sdk_root)
            startswith(name, "MacOSX") || continue
            endswith(name, ".sdk") || continue
            push!(candidates, joinpath(clt_sdk_root, name))
        end
    end
    push!(candidates, active_sdk_path)

    sdk_paths = unique_existing_dirs(candidates)
    sort!(sdk_paths; by = macos_sdk_version, rev = true)

    compatible = String[]
    for sdk_path in sdk_paths
        libcxx = joinpath(sdk_path, "usr", "include", "c++", "v1")
        isdir(libcxx) || continue
        has_unsupported_libcxx_builtins(libcxx) && continue
        push!(compatible, sdk_path)
    end
    return compatible
end

function macos_sdk_header_candidates(; clt_sdk_root::AbstractString,
                                      active_sdk_path::AbstractString,
                                      xcode_toolchain_path::AbstractString)
    dirs = String[]
    sdks = compatible_macos_sdk_paths(;
        clt_sdk_root,
        active_sdk_path,
    )

    if !isempty(sdks)
        sdk_path = first(sdks)
        append!(dirs, [
            joinpath(sdk_path, "usr", "include", "c++", "v1"),
            joinpath(sdk_path, "usr", "include"),
        ])
    end

    if !isempty(xcode_toolchain_path)
        append!(dirs, [
            joinpath(xcode_toolchain_path, "usr", "include", "c++", "v1"),
            joinpath(xcode_toolchain_path, "usr", "include"),
        ])
    end

    return unique_existing_dirs(dirs)
end

function default_cxx_header_dirs()
    dirs = String[]
    if Sys.isapple()
        clt_sdk_root = "/Library/Developer/CommandLineTools/SDKs"
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
        toolchain = if isempty(xcode_path)
            ""
        elseif occursin("Xcode", xcode_path)
            joinpath(xcode_path, "Toolchains", "XcodeDefault.xctoolchain")
        else
            xcode_path
        end

        append!(dirs, macos_sdk_header_candidates(;
            clt_sdk_root,
            active_sdk_path = sdk_path,
            xcode_toolchain_path = toolchain,
        ))
    end
    return dirs
end

end
