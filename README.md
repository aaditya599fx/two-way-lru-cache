# Two-Way Set-Associative Cache with LRU

Phase I prototype with 16 sets, two ways, 4-byte lines, and 32-bit byte
addresses. The cache holds 128 bytes and uses exact LRU, write-back, and
write-allocate.

Install Icarus Verilog and Make, then run `make test`. The testbench checks
15 transactions and reports nine refills and one write-back. Open
`build/cache.vcd` in GTKWave or view the [miss and hit](sim/cold-miss-hit.png)
and [dirty eviction](sim/lru-dirty-eviction.png) captures.

## Interface

- The CPU request transfers on a rising edge with `req_valid && req_ready`.
  Assert `req_write` for a store. One request may be in flight.
- `resp_valid` marks a one-cycle response. `resp_hit` reports the original
  lookup result. `resp_error` flags unaligned requests. `resp_rdata` carries
  the read word, echoes a written word, or returns zero on an error.
- A rising edge with `mem_valid && mem_ready` completes a memory command.
  The test model uses 4 KiB and responds on the third eligible clock edge.
  The cache decodes all 32 address bits.
- Reset is synchronous and invalidates the cache without flushing dirty
  lines. The behavioral backing memory preserves its contents.

## Files

- `src/` contains the synthesizable RTL.
- `tb/` contains the behavioral memory and testbench.
- `docs/` contains the [IEEE report](docs/phase1-report.pdf) and [diagrams](docs/architecture.md).
- `sim/` contains waveform captures and the VCD.

## Team assignments

| Member | Assigned scope |
| --- | --- |
| Aaditya Yadav | Behavioral memory, testbench, and waveform evidence |
| Gauri Mishra | Controller FSM, write policy, and top-level integration |
| Bhumi Rastogi | Tag and data arrays and address decoding |
| Ansh Sharma | LRU state and victim selection |
| Anugrah | IEEE report, diagrams, and README |

The prototype video link will be added when the video is available.
