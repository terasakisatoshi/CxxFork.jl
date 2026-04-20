using Test

makefile = read(joinpath(@__DIR__, "..", "..", "deps", "BuildBootstrap.Makefile"), String)

@testset "buildbootstrap_portability" begin
    @test occursin("CPPFLAGS += -DLIBRARY_EXPORTS", makefile)
end
