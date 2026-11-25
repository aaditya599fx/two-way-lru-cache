# FILE PURPOSE: shortcuts, so you can type "make test" or "make benchmark".
# IVERILOG is the Verilog compiler. "?=" means use this unless another value is given.
IVERILOG ?= iverilog
# VVP is the program that runs the compiled simulation.
VVP ?= vvp
# PYTHON is the Python program to use.
PYTHON ?= python3
# RTL = list of all design files in src/, sorted.
RTL := $(sort $(wildcard src/*.v))
# TB = the testbench files used for the basic test.
TB := tb/main_memory.v tb/tb_cache.v

# These names are commands, not real files.
.PHONY: test benchmark clean
# "make test" first builds build/tb_cache, if needed.
test: build/tb_cache
# Then it runs the simulation. $< means the first item needed (build/tb_cache).
	$(VVP) $<

# How to build build/tb_cache. Rebuild if any design or test file changes.
build/tb_cache: $(RTL) $(TB)
# Create the build folder if it does not exist.
	mkdir -p build
# Compile everything, with tb_cache as the top module. $@ means the output file name.
	$(IVERILOG) -g2012 -Wall -Wno-timescale -s tb_cache -o $@ $(RTL) $(TB)

# "make benchmark" runs the comparison experiment.
benchmark:
# Run the Python benchmark script and tell it which simulator tools to use.
	$(PYTHON) scripts/benchmark.py --iverilog "$(IVERILOG)" --vvp "$(VVP)"

# "make clean" removes generated files.
clean:
# Delete the build folder.
	rm -rf build
