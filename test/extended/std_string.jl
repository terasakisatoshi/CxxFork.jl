using Cxx
using Test

import Cxx.CxxStd

@testset "std_string conversions" begin
    jl_str = "Hello, World!"
    cxx_str = convert(Cxx.CxxStd.StdString, jl_str)

    @test convert(String, cxx_str) == jl_str
    @test String(cxx_str) == jl_str
    @test icxx"$cxx_str == $(convert(Cxx.CxxStd.StdString, jl_str));"
end
