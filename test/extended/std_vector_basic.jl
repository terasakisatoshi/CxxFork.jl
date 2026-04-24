using Cxx
using Test

@testset "std_vector basic int32" begin
    Cxx.cxxinclude("vector"; isAngled = true)

    v = icxx"std::vector<int32_t> v; v;"
    @test length(v) == 0
    @test size(v) == (0,)

    push!(v, Int32(7))
    @test length(v) == 1
    @test v[0] == Int32(7)

    push!(v, Int32(9))
    @test length(v) == 2
    @test v[1] == Int32(9)
    @test collect(v) == Int32[7, 9]

    deleteat!(v, 0)
    @test collect(v) == Int32[9]

    range_v = icxx"std::vector<int32_t>{1, 2, 3, 4};"
    deleteat!(range_v, 1:2)
    @test collect(range_v) == Int32[1, 4]

    wrapped = unsafe_wrap(DenseArray, v)
    @test length(wrapped) == 1
    @test wrapped[1] == Int32(9)

    converted = convert(cxxt"std::vector<int32_t>", Int32[1, 2, 3])
    @test length(converted) == 3
    @test converted[0] == Int32(1)
    @test converted[2] == Int32(3)
    @test convert(Vector{Int32}, converted) == Int32[1, 2, 3]
end
