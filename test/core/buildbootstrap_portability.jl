using Test

makefile = read(joinpath(@__DIR__, "..", "..", "deps", "BuildBootstrap.Makefile"), String)

@testset "buildbootstrap_portability" begin
    @test occursin("CPPFLAGS += -DLIBRARY_EXPORTS", makefile)
    @test occursin("LLVM_ARTIFACT_DIR ?=", makefile)
    @test occursin(raw"LLVM_LIBDIR := $(LLVM_ARTIFACT_DIR)/lib", makefile)
    @test occursin(raw"ifeq ($(OS), WINNT)", makefile)
    @test occursin("CPPFLAGS += -D_FILE_OFFSET_BITS=64", makefile)
    @test occursin("CXX := clang++.exe", makefile)
    @test occursin("COMMON_CXXFLAGS += -pthread", makefile)
    @test occursin("LDFLAGS += -fuse-ld=lld -pthread", makefile)
    @test occursin("WINDOWS_CLANG_VERBOSE", makefile)
    @test occursin("LDLIBS += -lmsvcrt", makefile)
    @test occursin(raw"LLVM_LINK_NAME := LLVM-$(firstword $(subst ., ,$(LLVM_VER)))jl", makefile)
end
