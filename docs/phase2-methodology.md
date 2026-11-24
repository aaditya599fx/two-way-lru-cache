# Phase II experiment

Run `make test benchmark` with Icarus Verilog, Make, and Python 3 installed.
The benchmark needs only the Python standard library. Optional chart generation
uses `python3 scripts/plot_results.py` with matplotlib installed.

Both caches hold 128 data bytes in 32 four-byte lines and share the controller,
write policy, CPU interface, and three-edge behavioral memory handshake.
The two-way design has 16 sets and the direct-mapped design has 32 sets.
The controller's INDEX_BITS parameter defaults to 4 for the existing cache,
and is set to 5 for the baseline.

Each experiment starts a fresh simulation with invalid cache lines and memory
word i initialized to 0xCAFE0000+i. Each workload has 2,048 accesses. The same
trace is replayed on both designs. Random generation uses Python random.Random
with seed 20261124. Generated trace files are retained in build/benchmarks.
The generator calls workloads afresh for each design so the PRNG sequence
is identical. All requests use aligned addresses within the 4 KiB model.

| Workload | Word-index sequence |
| --- | --- |
| sequential_fit | i modulo 32 |
| sequential_stream | i modulo 256 |
| stride_16 | (16 times i) modulo 256 |
| conflict_pair | alternate 0 and 32 |
| conflict_triple | repeat 0, 32, 64 |
| random_hot | uniform integer in [0, 23] |
| random_wide | uniform integer in [0, 255] |
| mixed_writes | uniform integer in [0, 63], every fourth access is a store |

Multiply word indices by four to obtain byte addresses. Only mixed_writes
contains stores. Its store payload is ((i+1)*2654435761) modulo 2^32.
The three random workloads consume one PRNG stream in the table's order.

An independent Python model represents each set as a list of full word
addresses ordered oldest first. It maintains cached values, dirty state, and
backing data. It emits expected hit status, response value, dirty write-back
address, and write-back payload for every transaction. The RTL testbench checks
each of these plus refill address, memory command counts, and response latency.
Failures terminate the simulation and benchmark command with nonzero status.

Response latency counts rising-edge intervals from request acceptance to the
edge that asserts resp_valid. Hits take one cycle. Refills add three cycles,
and a dirty write-back adds another three. Thus average response latency is
1 + 3*misses/accesses + 3*writebacks/accesses. The driver inserts idle gaps,
which are excluded. This metric describes the fixed-delay simulation model.
It does not measure throughput, physical clock period, or FPGA frequency.

Reported write-backs count completed evictions during each trace. Dirty lines
still resident at its end are excluded. There is no cache-flush command.
The Phase I directed suite additionally checks reset and alignment handling.
Reset discards dirty cache contents. The baseline uses the same controller,
so these comparisons isolate organization and replacement behavior while the
independent response and memory checks validate observed transactions.

There are eight workloads and two designs, totaling 32,768 checked benchmark
transactions. The directed suite adds 15 checks. This is simulation evidence.
No synthesis, FPGA implementation, or workload-general speedup is claimed.

## Storage accounting

Two-way storage is 32*(32 data + 26 tag + 1 valid + 1 dirty)+16 LRU = 1,936 bits.
Direct-mapped storage is 32*(32 data + 25 tag + 1 valid + 1 dirty) = 1,888 bits.
This excludes controller registers, wires, and combinational logic and is an
analytical count. Equal data capacity does not imply equal implementation area.

## Report source

The final report uses the IEEEtran conference document class. From the docs/
directory, run `tectonic phase2-report.tex` with internet access for any missing
LaTeX dependencies. Results tables are stored alongside the CSV in
results/report-table.tex and reproduced in the report source. If a workload
changes, rerun the benchmark and plotter, update the report's table and
discussion to match, and rebuild the PDF.
