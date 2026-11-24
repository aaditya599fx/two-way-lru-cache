# Phase II interview preparation

Read the implementation and run `make test benchmark` before rehearsing.
The answers below describe the current simulation prototype.

## Everyone

**What did you build?** A blocking, 128-byte, two-way set-associative word cache
with exact LRU, write-back, and write-allocate. Phase II adds an equal-data-capacity
direct-mapped baseline, eight deterministic workloads, and measured results.

**What is a hit?** A selected set contains a valid line whose stored tag matches
the requested tag. The data comes from that way.

**How is the address split?** The two-way cache uses tag [31:6], index [5:2],
offset [1:0]. Direct mapping uses tag [31:7], index [6:2], offset [1:0].
Both have 32 lines. Their set counts differ.

**Why does one bit implement exact LRU?** With two valid ways, using one makes
the other the least recently used. Each hit or fill writes the complement
of the touched way. Invalid lines have priority over valid lines.

**What happens on a dirty miss?** Latch the request and victim way. Reconstruct
the victim's address from its stored tag, the selected set, and zero offset.
Hold the memory write until acknowledged, then issue a refill. Install the
new data and tag, update validity, dirty state and LRU, then respond.

**Write-back versus write-allocate?** Write-back postpones an updated line's
memory write until eviction. Write-allocate installs a line on a store miss.
Our one-word line lets the requested write word replace the refill word.
The prototype still issues the refill on a store miss.

**What did the measurements show?** Read results/benchmarks.csv. Conflict-pair
misses fell from 2048 to 2. Wide random produced 1776 versus 1777 misses.
Mixed writes produced 1028 versus 1040 misses and 384 versus 383 write-backs,
with direct mapping listed first. Associativity's benefit depends on mapping
and reuse.

**Why does conflict_triple still miss every time?** Three blocks compete for
two ways of one set. Cyclic access evicts each block before its next use.

**Why does stride_16 thrash even though it touches only sixteen words?**
Those words map to too few sets. They all have the same low four word-index
bits in the two-way cache, so they compete in a single set. Direct mapping
uses two sets for that trace. Total capacity alone cannot prevent conflicts.

**How were values verified?** A separate Python cache model predicts hits,
data, victim address and payload. The testbench checks those predictions
against RTL responses and memory commands for all 32768 benchmark accesses.

**What does average latency include?** Request-acceptance edge through
response-assertion edge. Hit = 1 cycle, clean miss = 4, dirty miss = 7.
Idle gaps and physical propagation delays are excluded. The 10 ns testbench
clock is a simulation setting.

**What are the limits?** Word accesses only, one outstanding request, 4 KiB
test memory, fixed memory delay, no flush, and reset discards dirty lines.
The study uses synthetic traces and one fixed random seed. There are no
synthesis resource or frequency measurements.

## Aaditya Yadav

Be ready to explain tb/main_memory.v, tb/tb_cache.v, and tb/tb_workload.sv.
Explain why memory ready is asserted when delay_count reaches two, why the
memory command stays stable until acknowledgment, and how the testbench
checks victim addresses and data. Show the dirty-write-back directed check.

## Gauri Mishra

Walk through IDLE, TAG_COMPARE, WRITEBACK, REFILL, DONE in cache_controller.v.
Explain why INDEX_BITS changes victim-address reconstruction and why its
default preserves the two-way interface. Explain response/error signaling
and derive the latency formula from rising edges.

## Bhumi Rastogi

Walk through tag_array.v, data_array.v, address_decode.v, and
direct_mapped_cache.v. Derive 128 bytes from sets*ways*line bytes.
Explain why the baseline needs 25 tag bits and why invalid data-array
contents cannot cause a hit. Derive the analytical storage counts.

## Ansh Sharma

Walk through lru_unit.v. Explain invalid-way priority, complement updates,
and set-local recency. Predict the outcomes for pair and triple conflicts
before opening the CSV. Explain why two-way LRU can occasionally lose to
direct mapping on an individual trace.

## Anugra

Explain the report's abstract, research context, methodology, results, and
conclusion. Identify the distinction between measured values and analytical
storage counts. Explain the reference-model strategy and study limitations.
Describe the review or documentation changes you actually made.

## Practice exercise

For aligned addresses 0x000, 0x080, and 0x100, predict the set and tag under
both organizations. Simulate the sequence A, B, A, C by hand, then identify
the two-way victim. Repeat with a write to A and identify whether that
sequence itself triggers a write-back. It evicts B, so dirty A survives.
