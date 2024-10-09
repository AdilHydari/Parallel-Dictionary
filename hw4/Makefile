# Makefile for Building benchmark_assembler_mem on ARM64

# Compiler and Assembler
CXX := g++
AS := as

# Compiler and Assembler Flags
CXXFLAGS := -O2 -Wall -std=c++17
ASFLAGS :=           # Ensure 64-bit mode for ARM64 assembly

# Linker Flags
LDFLAGS := -lpthread

# Target Executable
TARGET := benchmark_assembler_mem

# Source Files
CPP_SRC := benchmark_assembler_mem.cpp
ASM_SRC := memory_timingarm64.s

# Object Files
CPP_OBJ := $(CPP_SRC:.cpp=.o)
ASM_OBJ := $(ASM_SRC:.s=.o)

# Default Target
all: $(TARGET)

# Link Object Files to Create Executable
$(TARGET): $(CPP_OBJ) $(ASM_OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

# Compile C++ Source Files to Object Files
%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

# Assemble Assembly Source Files to Object Files
%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $<

# Clean Build Artifacts
clean:
	rm -f $(TARGET) $(CPP_OBJ) $(ASM_OBJ)

# Phony Targets (Not Actual Files)
.PHONY: all clean
