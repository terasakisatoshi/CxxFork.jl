using Test

workflow = read(joinpath(@__DIR__, "..", "..", ".github", "workflows", "ci.yml"), String)

@testset "ci_portability" begin
    @test occursin("name: Toolchain info", workflow)
    @test occursin("WINDOWS_CLANG_VERBOSE: \"1\"", workflow)
    @test occursin("command -v llvm-nm.exe || true", workflow)
    @test occursin("libmsvcrt.a", workflow)
end
