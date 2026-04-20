using Test
using Cxx

@testset "smoke_load" begin
    @test isdefined(Cxx, :CxxCore)
    @test isdefined(Cxx, Symbol("@cxx"))
    @test isdefined(Cxx, Symbol("@icxx_str"))
end
