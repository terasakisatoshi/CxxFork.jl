if "@stdlib" ∉ LOAD_PATH
    push!(LOAD_PATH, "@stdlib")
end

using Downloads

const LLVM_SOURCE_PARENT = joinpath(@__DIR__, "usr", "src")

function tar_compatible_path(path::AbstractString; windows::Bool = Sys.iswindows())
    normalized = normpath(path)
    windows || return normalized

    msys = replace(normalized, '\\' => '/')
    drive_match = match(r"^([A-Za-z]):/(.*)$", msys)
    if drive_match !== nothing
        drive, rest = drive_match.captures
        return "/$(lowercase(drive))/$(rest)"
    end
    return msys
end

function extract_tar_archive!(archive::AbstractString, dest::AbstractString)
    archive_path = tar_compatible_path(archive)
    dest_path = tar_compatible_path(dest)
    run(`tar -xf $archive_path -C $dest_path`)
end

function ensure_llvm_sources!(llvm_ver::VersionNumber)
    root = joinpath(LLVM_SOURCE_PARENT, "llvm-project-$(llvm_ver)")
    isdir(root) && return root

    mkpath(LLVM_SOURCE_PARENT)

    archive = root * ".src.tar.xz"
    extracted = root * ".src"
    tag = "llvmorg-$(llvm_ver)"
    url = "https://github.com/llvm/llvm-project/releases/download/$tag/llvm-project-$(llvm_ver).src.tar.xz"

    isfile(archive) || Downloads.download(url, archive)
    extract_tar_archive!(archive, LLVM_SOURCE_PARENT)

    if isdir(extracted) && !isdir(root)
        mv(extracted, root)
    end

    isdir(root) || error("LLVM sources were extracted but $root was not created")
    return root
end
