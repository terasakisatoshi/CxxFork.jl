using Test
using Cxx

Cxx.ENABLE_CXX_EXCEPTIONS || error(
    "test/optin/exceptions_basic.jl requires CXX_ENABLE_EXCEPTIONS=1"
)

cxx"""
#include <stdexcept>
#include <vector>

class optin_test_exception : public std::exception {
public:
    int value;

    explicit optin_test_exception(int value) : value(value) {}
};
"""

import Base: showerror

@exception function showerror(io::IO, e::cxxt"optin_test_exception&")
    print(io, icxx"$e.value;")
end

@testset "exceptions_basic" begin
    @testset "built-in throw translation" begin
        err = try
            icxx"throw 20;"
            error("unexpected success")
        catch err
            err
        end

        @test err isa Cxx.CxxException
        @test sprint(showerror, err) == "20"
    end

    @testset "user-defined exception formatting" begin
        err = try
            icxx"throw optin_test_exception(5);"
            error("unexpected success")
        catch err
            err
        end

        @test err isa Cxx.CxxException
        @test sprint(showerror, err) == "5"
    end

    @testset "std::length_error formatting" begin
        v = icxx"std::vector<int>{1, 2, 3};"
        err = try
            icxx"$v.resize($v.max_size() + 1);"
            error("unexpected success")
        catch err
            err
        end

        @test err isa Cxx.CxxException{:St12length_error}
        @test startswith(sprint(showerror, err), "vector")
    end
end
