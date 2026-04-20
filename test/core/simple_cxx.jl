using Test
using Cxx

cxx"""
int cxx_smoke_add(int x) {
    return x + 1;
}
"""

@testset "simple_cxx" begin
    @test @cxx(cxx_smoke_add(41)) == 42
    @test icxx"1 + 2;" == 3
end
