if "@stdlib" ∉ LOAD_PATH
    push!(LOAD_PATH, "@stdlib")
end

using Downloads

const LLVM_SOURCE_PARENT = joinpath(@__DIR__, "usr", "src")

function ensure_llvm_sources!(llvm_ver::VersionNumber)
    root = joinpath(LLVM_SOURCE_PARENT, "llvm-project-$(llvm_ver)")
    isdir(root) && return root

    mkpath(LLVM_SOURCE_PARENT)

    archive = root * ".src.tar.xz"
    extracted = root * ".src"
    tag = "llvmorg-$(llvm_ver)"
    url = "https://github.com/llvm/llvm-project/releases/download/$tag/llvm-project-$(llvm_ver).src.tar.xz"

    isfile(archive) || Downloads.download(url, archive)
    run(`tar -xf $archive -C $LLVM_SOURCE_PARENT`)

    if isdir(extracted) && !isdir(root)
        mv(extracted, root)
    end

    isdir(root) || error("LLVM sources were extracted but $root was not created")
    return root
end
