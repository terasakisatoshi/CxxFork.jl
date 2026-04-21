using Cxx
using Test

@testset "std_vector wrappers" begin
    Cxx.cxxinclude("vector"; isAngled = true)
    Cxx.cxxinclude("string"; isAngled = true)

    string_vector = icxx"""std::vector<std::string>{"foo", "bar"};"""
    @test length(string_vector) == 2
    @test String(string_vector[0]) == "foo"
    @test String(string_vector[1]) == "bar"
    @test convert(Vector{String}, string_vector) == ["foo", "bar"]

    wrapped_strings = unsafe_wrap(DenseArray, string_vector)
    @test String(wrapped_strings[1]) == "foo"
    @test String(wrapped_strings[2]) == "bar"

    bool_vector = icxx"std::vector<bool>{true, false, true};"
    @test length(bool_vector) == 3
    @test bool_vector[0] == true
    @test bool_vector[1] == false
    @test convert(Vector{Bool}, bool_vector) == Bool[true, false, true]

    wrapped_bools = unsafe_wrap(DenseArray, bool_vector)
    @test wrapped_bools[1] == true
    @test wrapped_bools[2] == false
    @test wrapped_bools[3] == true
end
