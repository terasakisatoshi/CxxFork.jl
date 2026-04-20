include Make.inc

CXX ?= c++
PREFIX ?= $(CURDIR)/usr
BASE_JULIA_BIN ?= $(shell dirname "$$(command -v julia)")
JULIA_PREFIX ?= $(abspath $(BASE_JULIA_BIN)/..)
LLVM_VER ?=
LLVM_SOURCE_ROOT ?=
CLANG_ARTIFACT_DIR ?=
LLVM_GENERATED_INCLUDE_DIR ?=
LLVM_COMPAT_INCLUDE_DIR ?= $(PREFIX)/include

ifeq ($(strip $(LLVM_SOURCE_ROOT)),)
$(error LLVM_SOURCE_ROOT must be set)
endif

ifeq ($(strip $(CLANG_ARTIFACT_DIR)),)
$(error CLANG_ARTIFACT_DIR must be set)
endif

ifeq ($(strip $(LLVM_GENERATED_INCLUDE_DIR)),)
$(error LLVM_GENERATED_INCLUDE_DIR must be set)
endif

JULIA_INCLUDE_DIR := $(JULIA_PREFIX)/include
JULIA_HEADERS_DIR := $(JULIA_INCLUDE_DIR)/julia
JULIA_LIBDIR := $(JULIA_PREFIX)/lib
JULIA_LLVM_LIBDIR := $(JULIA_LIBDIR)/julia
CLANG_INCLUDE_DIR := $(CLANG_ARTIFACT_DIR)/include
CLANG_LIBDIR := $(CLANG_ARTIFACT_DIR)/lib
LLVM_PUBLIC_INCLUDE_DIR := $(LLVM_SOURCE_ROOT)/llvm/include
CLANG_SOURCE_INCLUDE_DIR := $(LLVM_SOURCE_ROOT)/clang/include
CLANG_PRIVATE_INCLUDE_DIR := $(LLVM_SOURCE_ROOT)/clang/lib

INCLUDE_DIRS := $(LLVM_COMPAT_INCLUDE_DIR) $(JULIA_HEADERS_DIR) $(JULIA_INCLUDE_DIR) $(CLANG_INCLUDE_DIR) $(LLVM_GENERATED_INCLUDE_DIR) $(LLVM_PUBLIC_INCLUDE_DIR) $(CLANG_SOURCE_INCLUDE_DIR) $(CLANG_PRIVATE_INCLUDE_DIR)
CPPFLAGS += $(addprefix -I,$(INCLUDE_DIRS))
CPPFLAGS += -DLLVM_DISABLE_ABI_BREAKING_CHECKS_ENFORCING=1 -DLLVM_ENABLE_DUMP=1 -DLLVM_NDEBUG

COMMON_CXXFLAGS := -std=c++17 -fPIC -fno-rtti -O0 -g

ifeq ($(OS), Darwin)
SHARED_LDFLAG := -dynamiclib
else
SHARED_LDFLAG := -shared
endif

JULIA_LIB_SEARCH_DIRS := $(JULIA_LIBDIR) $(JULIA_LLVM_LIBDIR)
LIB_DIRS := $(CLANG_LIBDIR) $(JULIA_LIB_SEARCH_DIRS)
RPATH_FLAGS := $(foreach dir,$(LIB_DIRS),-Wl,-rpath,$(dir))
LDFLAGS += $(addprefix -L,$(LIB_DIRS))
LDFLAGS += $(RPATH_FLAGS)
LDLIBS += -lclang-cpp -lLLVM -ljulia

all: $(PREFIX)/lib/libcxxffi.$(SHLIB_EXT) $(PREFIX)/clang_constants.jl

$(PREFIX)/lib:
	mkdir -p $@

$(PREFIX)/lib/bootstrap.o: ../src/bootstrap.cpp BuildBootstrap.Makefile | $(PREFIX)/lib
	@$(call PRINT_CC, $(CXX) $(COMMON_CXXFLAGS) $(CPPFLAGS) -c ../src/bootstrap.cpp -o $@)

$(PREFIX)/lib/libcxxffi.$(SHLIB_EXT): $(PREFIX)/lib/bootstrap.o | $(PREFIX)/lib
	@$(call PRINT_LINK, $(CXX) $(SHARED_LDFLAG) -o $@ $< $(LDFLAGS) $(LDLIBS))

$(PREFIX)/clang_constants.jl: ../src/cenumvals.jl.h $(PREFIX)/lib/libcxxffi.$(SHLIB_EXT)
	@$(call PRINT_PERL, $(CXX) -E -P -x c++ $(COMMON_CXXFLAGS) $(CPPFLAGS) -DJULIA ../src/cenumvals.jl.h > $@)

clean:
	rm -f $(PREFIX)/lib/bootstrap.o $(PREFIX)/lib/libcxxffi.$(SHLIB_EXT) $(PREFIX)/clang_constants.jl
