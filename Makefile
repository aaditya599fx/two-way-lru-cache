IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
RTL := $(sort $(wildcard src/*.v))
TB := tb/main_memory.v tb/tb_cache.v

.PHONY: test benchmark clean
test: build/tb_cache
	$(VVP) $<

build/tb_cache: $(RTL) $(TB)
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -Wno-timescale -s tb_cache -o $@ $(RTL) $(TB)

benchmark:
	$(PYTHON) scripts/benchmark.py --iverilog "$(IVERILOG)" --vvp "$(VVP)"

clean:
	rm -rf build
