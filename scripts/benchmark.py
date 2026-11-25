#!/usr/bin/env python3
# FILE PURPOSE: runs the experiment. It makes request patterns, works out the correct answers,
# runs both caches in the simulator, checks them, and saves the results.
# A short description of this file.
"""Generate deterministic traces and check RTL against an independent LRU model."""
# Tool for reading command-line options.
import argparse
# Tool for writing CSV (table) files.
import csv
# Tool for writing JSON files.
import json
# Tool for random numbers.
import random
# Tool for searching text patterns.
import re
# Tool for splitting a command text into parts.
import shlex
# Tool for running other programs.
import subprocess
# Tool for system things, like the error output.
import sys
# Tool for handling file and folder paths.
from pathlib import Path

# ROOT = the main project folder (two levels above this file).
ROOT = Path(__file__).resolve().parents[1]
# Each pattern has 2048 memory accesses.
COUNT = 2048
# The fixed "seed" makes the random numbers the same on every run.
SEED = 20261124


# This function creates the 8 access patterns.
def workloads():
    # Note: all positions stay inside the 4 KiB memory.
    """Word indices are within the 4 KiB behavioral memory."""
    # Create a random number generator using the seed.
    rng = random.Random(SEED)
    # A table that maps each pattern name to its list of word numbers.
    patterns = {
        # 1) Go through words 0 to 31 again and again. This fits in the cache.
        "sequential_fit": [i % 32 for i in range(COUNT)],
        # 2) Go through 256 words in order. This is bigger than the cache.
        "sequential_stream": [i % 256 for i in range(COUNT)],
        # 3) Jump 16 words each time. These all crowd into very few sets.
        "stride_16": [(i * 16) % 256 for i in range(COUNT)],
        # 4) Switch between words 0 and 32, which want the same set.
        "conflict_pair": [0 if i % 2 == 0 else 32 for i in range(COUNT)],
        # 5) Rotate between 3 words (0, 32, 64) that want the same set.
        "conflict_triple": [[0, 32, 64][i % 3] for i in range(COUNT)],
        # 6) Random picks from only 24 words.
        "random_hot": [rng.randrange(24) for _ in range(COUNT)],
        # 7) Random picks from 256 words.
        "random_wide": [rng.randrange(256) for _ in range(COUNT)],
        # 8) Random picks from 64 words. Some of these will be writes.
        "mixed_writes": [rng.randrange(64) for _ in range(COUNT)],
    # End of the pattern table.
    }
    # Go through the patterns one by one.
    for name, addresses in patterns.items():
        # "yield" hands back one pattern at a time: its name and a list of requests.
        yield name, [
            # Part 1: write flag (only in mixed_writes, every 4th access). Part 2: byte address = word x 4.
            (int(name == "mixed_writes" and i % 4 == 0), word * 4,
             # Part 3: write data, a mixed-up looking 32-bit number. "& 0xFFFFFFFF" keeps it 32 bits.
             ((i + 1) * 2654435761) & 0xFFFFFFFF)
            # Make one request for every word number; i is its position in the list.
            for i, word in enumerate(addresses)
        # End of the request list.
        ]


# The "reference model": a simple Python copy of a correct cache. It gives the expected answers.
def reference(transactions, ways):
    # Ordered sets contain full word addresses, oldest first. Full addresses
    # make victim reconstruction independent of the RTL's tag concatenation.
    # Make the sets: 32 sets if 1 way, 16 sets if 2 ways. Each set is a list, oldest first.
    sets = [[] for _ in range(32 // ways)]
    # The data currently inside the cache.
    data = {}
    # Which words in the cache have been changed.
    dirty = set()
    # A copy of main memory with the same starting values as the Verilog memory.
    backing = {word: 0xCAFE0000 + word for word in range(1024)}
    # The list of expected results.
    rows = []
    # Handle each request one by one.
    for store, address, payload in transactions:
        # Change the byte address into a word number.
        word = address // 4
        # Find the set this word belongs to (remainder after dividing by the number of sets).
        resident = sets[word % len(sets)]
        # Hit = 1 if the word is already in that set.
        hit = int(word in resident)
        # Assume no write-back for now.
        writeback = 0
        # Assume there is no removed address or data.
        victim_address = victim_data = 0
        # If it is a hit...
        if hit:
            # ...take it out of the list. It is added again at the end to mark it as newest.
            resident.remove(word)
        # If it is a miss...
        else:
            # ...and the set is full...
            if len(resident) == ways:
                # ...remove the first item, which is the least recently used.
                victim = resident.pop(0)
                # If that removed word was changed...
                if victim in dirty:
                    # ...a write-back is needed.
                    writeback = 1
                    # Remember its byte address.
                    victim_address = victim * 4
                    # Remember its data.
                    victim_data = data[victim]
                    # Save its data into the memory copy.
                    backing[victim] = victim_data
                    # It is no longer marked as changed.
                    dirty.remove(victim)
                # Remove its data from the cache.
                del data[victim]
            # Load the new word from memory.
            data[word] = backing[word]
        # Put this word at the end of the list: it is now the most recently used.
        resident.append(word)
        # If the request is a write...
        if store:
            # ...put the new data in the cache...
            data[word] = payload
            # ...and mark it as changed.
            dirty.add(word)
        # Save what we expect for this request...
        rows.append((store, address, payload, hit, data[word],
                     # ...including any write-back details.
                     writeback, victim_address, victim_data))
    # Return all the expected results.
    return rows


# A helper function that runs an external command.
def run(command):
    # Run it from the project folder and collect its output.
    result = subprocess.run(command, cwd=ROOT, capture_output=True,
                            # Get the output as text, and give up after 60 seconds.
                            text=True, timeout=60)
    # If the command failed...
    if result.returncode:
        # ...print its output...
        print(result.stdout + result.stderr, file=sys.stderr)
        # ...and stop the script with an error.
        result.check_returncode()
    # Otherwise return the normal output.
    return result.stdout


# The main function: runs the whole experiment.
def main():
    # Prepare to read command-line options.
    parser = argparse.ArgumentParser()
    # Option: which Verilog compiler to use.
    parser.add_argument("--iverilog", default="iverilog")
    # Option: which simulator runner to use.
    parser.add_argument("--vvp", default="vvp")
    # Read the options.
    args = parser.parse_args()
    # Folder for the generated benchmark files.
    build = ROOT / "build/benchmarks"
    # Create it if it does not exist.
    build.mkdir(parents=True, exist_ok=True)
    # Folder for the results.
    results_dir = ROOT / "results"
    # Create it if it does not exist.
    results_dir.mkdir(exist_ok=True)
    # Make a sorted list of all the Verilog design files.
    rtl = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "src").glob("*.v"))
    # This will hold one result row per test.
    records = []
    # This will hold the simulator output.
    logs = []
    # Test both designs. Each entry is: name, number of ways, and the DIRECT setting.
    for design, ways, direct in [("direct_mapped", 1, 1), ("two_way_lru", 2, 0)]:
        # Name of the compiled program.
        executable = build / design
        # Compile the Verilog for this design.
        run(shlex.split(args.iverilog) + [
            # Compiler options: new Verilog features, show warnings, and choose the top module.
            "-g2012", "-Wall", "-Wno-timescale", "-s", "tb_workload",
            # Set DIRECT to choose the cache, and name the output file.
            f"-Ptb_workload.DIRECT={direct}", "-o", str(executable),
            # Add all design files, the memory and the testbench.
            *rtl, "tb/main_memory.v", "tb/tb_workload.sv",
        # End of the compile command.
        ])
        # Run each of the 8 patterns.
        for name, transactions in workloads():
            # Get the correct answers from the Python model.
            rows = reference(transactions, ways)
            # Name of the trace file for this test.
            trace = build / f"{design}-{name}.txt"
            # Write the trace file...
            trace.write_text("".join(
                # ...one line per request, mostly in hexadecimal, in the order the testbench reads it.
                f"{s} {a:08x} {d:08x} {h} {v:08x} {w} {va:08x} {vd:08x}\n"
                # The short letters are the 8 values of each row.
                for s, a, d, h, v, w, va, vd in rows
            # End of the file writing.
            ))
            # Run the simulation using this trace.
            output = run(shlex.split(args.vvp) + [str(executable), f"+TRACE={trace}"])
            # Find the RESULT line and pick out its 5 numbers.
            match = re.search(r"RESULT (\d+) (\d+) (\d+) (\d+) (\d+)", output)
            # If there is no RESULT line...
            if not match:
                # ...something went wrong, so stop.
                raise RuntimeError(output)
            # Turn the 5 numbers into integers. "misses" is the count of memory reads (one per miss).
            count, hits, misses, writebacks, cycles = map(int, match.groups())
            # Double-check that all 2048 requests ran.
            assert count == COUNT
            # Double-check that the hit count matches Python.
            assert hits == sum(row[3] for row in rows)
            # Double-check that the write-back count matches Python.
            assert writebacks == sum(row[5] for row in rows)
            # Save one row of results...
            records.append(dict(
                # ...with the design, pattern, number of accesses and hits...
                design=design, workload=name, accesses=count, hits=hits,
                # ...misses, write-backs and total cycles...
                misses=misses, writebacks=writebacks, response_cycles=cycles,
                # ...the miss rate (misses divided by accesses)...
                miss_rate=round(misses / count, 8),
                # ...and the average cycles per access.
                average_response_cycles=round(cycles / count, 8),
            # End of the result row.
            ))
            # Save the simulator output for the log.
            logs.append(f"{design}/{name}\n{output}")
            # Print a short summary on the screen...
            print(f"{design:14} {name:18} misses={misses:4} "
                  # ...with write-backs and average cycles.
                  f"writebacks={writebacks:3} cycles/access={cycles/count:.4f}")
    # Nice names of the patterns, for the report table.
    labels = ["Sequential fit", "Sequential stream", "Stride 16", "Conflict pair",
              # The rest of the names.
              "Conflict triple", "Random hot", "Random wide", "Mixed writes"]
    # This will hold the table rows.
    table = []
    # Pair the results: the first 8 are direct-mapped, the last 8 are two-way.
    for label, direct, two_way in zip(labels, records[:8], records[8:]):
        # Add one table row in LaTeX format.
        table.append(
            # Pattern name and the misses of both designs.
            f"{label} & {direct['misses']} & {two_way['misses']} & "
            # Average cycles of direct-mapped.
            f"{direct['average_response_cycles']:.3f} & "
            # Average cycles of two-way, then the LaTeX end-of-row mark (two backslashes; chr(92) is one backslash).
            f"{two_way['average_response_cycles']:.3f} " + chr(92) * 2
        # End of this row.
        )
    # Save the table for the report.
    (results_dir / "report-table.tex").write_text("\n".join(table) + "\n")
    # Open the CSV file for writing.
    with (results_dir / "benchmarks.csv").open("w", newline="") as stream:
        # Set up the CSV writer, using the result names as column headings.
        writer = csv.DictWriter(stream, fieldnames=records[0].keys(), lineterminator="\n")
        # Write the heading row.
        writer.writeheader()
        # Write all the result rows.
        writer.writerows(records)
    # Save the simulation log.
    (results_dir / "simulation.log").write_text("\n".join(logs))
    # Collect extra details about this run...
    metadata = dict(
        # ...the seed, accesses per pattern and number of patterns...
        random_seed=SEED, accesses_per_workload=COUNT, workloads=8,
        # ...the total number of checked requests...
        checked_transactions=len(records)*COUNT,
        # ...how time was measured...
        timing="Acceptance rising edge to response rising edge; excludes idle gaps",
        # ...the formula for time per request...
        latency_formula="1 + 3*miss + 3*dirty_writeback",
        # ...and the simulator version.
        simulator=run(shlex.split(args.iverilog) + ["-V"]).splitlines()[0],
    # End of the details.
    )
    # Save these details as a JSON file.
    (results_dir / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")


# This is true only when the file is run directly.
if __name__ == "__main__":
    # Start the main function.
    main()
