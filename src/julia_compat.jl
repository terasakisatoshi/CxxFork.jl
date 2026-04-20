module JuliaCompat

export current_world, generating_output

current_world() = Base.get_world_counter()

function generating_output()
    if isdefined(Base, :generating_output)
        return Base.generating_output()
    end
    return ccall(:jl_generating_output, Cint, ()) != 0
end

end
