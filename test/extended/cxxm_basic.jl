using Cxx
using Test

function capture_eval_error(ex)
    try
        Core.eval(@__MODULE__, ex)
        nothing
    catch err
        err
    end
end

@testset "cxxm basic" begin
    unsupported = "@cxxm is not supported on the Julia 1.12 baseline in this build."

    err = capture_eval_error(quote
        @cxxm "int foofunc(int x)" begin
            x + 1
        end
    end)

    @test err isa ErrorException
    @test occursin(unsupported, sprint(showerror, err))

    cxx"""
    struct foostruct {
        int x;
        int Add1();
    };
    """

    err = capture_eval_error(quote
        @cxxm "int foostruct::Add1()" begin
            icxx"return $this->x;" + 1
        end
    end)

    @test err isa ErrorException
    @test occursin(unsupported, sprint(showerror, err))

    err = capture_eval_error(quote
        begin
            @cxxm "not a declaration" begin
                1
            end
        end
    end)

    @test err isa ErrorException
    @test occursin(unsupported, sprint(showerror, err))
end
