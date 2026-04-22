using Cxx
using Test

cxx"""
#include <cstdint>

class Bill {
public:
    std::int64_t a;
    std::int64_t b;
};

std::int64_t sum_bill(Bill *m) {
    return m->a + m->b;
}
"""

mutable struct Bill
    a::Int64
    b::Int64
end

struct FrozenBill
    a::Int64
    b::Int64
end

@testset "jpcpp basic" begin
    @test @cxx(sum_bill(jpcpp"Bill"(Bill(1, 2)))) == Int64(3)

    err = try
        jpcpp"Bill"(FrozenBill(1, 2))
        nothing
    catch e
        e
    end

    @test err isa ErrorException
    @test occursin("Can only pass pointers to mutable values", sprint(showerror, err))
    @test occursin("use an array instead", sprint(showerror, err))
end
