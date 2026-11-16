IVERILOG ?= iverilog
VVP ?= vvp
RTL := $(sort $(wildcard src/*.v))
TB := tb/main_memory.v tb/tb_cache.v

.PHONY: test clean
test: build/tb_cache
	$(VVP) $<

build/tb_cache: $(RTL) $(TB)
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -Wno-timescale -s tb_cache -o $@ $(RTL) $(TB)

clean:
	rm -rf build
