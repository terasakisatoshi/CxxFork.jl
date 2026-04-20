using Test

bootstrap = read(joinpath(@__DIR__, "..", "..", "src", "bootstrap.cpp"), String)

@testset "bootstrap_portability" begin
    @test occursin("#ifdef _WIN32\n#include <windows.h>\n#else\n#include <dlfcn.h>\n#endif", bootstrap)
    @test occursin("static void *resolve_dynamic_symbol(const char *name)", bootstrap)
    @test occursin("resolve_dynamic_symbol(\"jl_type_to_llvm\")", bootstrap)
    @test !occursin("_OS_WINDOWS_", bootstrap)
    @test occursin("#ifndef _WIN32\n#include <signal.h>", bootstrap)
    @test occursin("#endif // _WIN32", bootstrap)
end
