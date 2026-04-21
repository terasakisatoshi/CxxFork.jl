using Cxx
using Test

cxx"""
#include <map>
#include <string>

using Map17 = std::map<std::string, std::string>;

Map17 get_map17() {
    return Map17({{"hello", "world"}, {"everything", "awesome"}});
}
"""

@testset "std_map basic" begin
    m = @cxx get_map17()
    @test length(m) == 2
    @test Dict(String(k) => String(v) for (k, v) in m) ==
        Dict("everything" => "awesome", "hello" => "world")

    int_map = icxx"std::map<int32_t, int32_t> m; m.emplace(1, 10); m.emplace(2, 20); m;"
    @test length(int_map) == 2
    @test collect(int_map) == Any[Int32(1) => Int32(10), Int32(2) => Int32(20)]
end
