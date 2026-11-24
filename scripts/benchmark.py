#!/usr/bin/env python3
"""Generate deterministic traces and check RTL against an independent LRU model."""
import argparse
import csv
import json
import random
import re
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COUNT = 2048
SEED = 20261124


def workloads():
    """Word indices are within the 4 KiB behavioral memory."""
    rng = random.Random(SEED)
    patterns = {
        "sequential_fit": [i % 32 for i in range(COUNT)],
        "sequential_stream": [i % 256 for i in range(COUNT)],
        "stride_16": [(i * 16) % 256 for i in range(COUNT)],
        "conflict_pair": [0 if i % 2 == 0 else 32 for i in range(COUNT)],
        "conflict_triple": [[0, 32, 64][i % 3] for i in range(COUNT)],
        "random_hot": [rng.randrange(24) for _ in range(COUNT)],
        "random_wide": [rng.randrange(256) for _ in range(COUNT)],
        "mixed_writes": [rng.randrange(64) for _ in range(COUNT)],
    }
    for name, addresses in patterns.items():
        yield name, [
            (int(name == "mixed_writes" and i % 4 == 0), word * 4,
             ((i + 1) * 2654435761) & 0xFFFFFFFF)
            for i, word in enumerate(addresses)
        ]


def reference(transactions, ways):
    # Ordered sets contain full word addresses, oldest first. Full addresses
    # make victim reconstruction independent of the RTL's tag concatenation.
    sets = [[] for _ in range(32 // ways)]
    data = {}
    dirty = set()
    backing = {word: 0xCAFE0000 + word for word in range(1024)}
    rows = []
    for store, address, payload in transactions:
        word = address // 4
        resident = sets[word % len(sets)]
        hit = int(word in resident)
        writeback = 0
        victim_address = victim_data = 0
        if hit:
            resident.remove(word)
        else:
            if len(resident) == ways:
                victim = resident.pop(0)
                if victim in dirty:
                    writeback = 1
                    victim_address = victim * 4
                    victim_data = data[victim]
                    backing[victim] = victim_data
                    dirty.remove(victim)
                del data[victim]
            data[word] = backing[word]
        resident.append(word)
        if store:
            data[word] = payload
            dirty.add(word)
        rows.append((store, address, payload, hit, data[word],
                     writeback, victim_address, victim_data))
    return rows


def run(command):
    result = subprocess.run(command, cwd=ROOT, capture_output=True,
                            text=True, timeout=60)
    if result.returncode:
        print(result.stdout + result.stderr, file=sys.stderr)
        result.check_returncode()
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iverilog", default="iverilog")
    parser.add_argument("--vvp", default="vvp")
    args = parser.parse_args()
    build = ROOT / "build/benchmarks"
    build.mkdir(parents=True, exist_ok=True)
    results_dir = ROOT / "results"
    results_dir.mkdir(exist_ok=True)
    rtl = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "src").glob("*.v"))
    records = []
    logs = []
    for design, ways, direct in [("direct_mapped", 1, 1), ("two_way_lru", 2, 0)]:
        executable = build / design
        run(shlex.split(args.iverilog) + [
            "-g2012", "-Wall", "-Wno-timescale", "-s", "tb_workload",
            f"-Ptb_workload.DIRECT={direct}", "-o", str(executable),
            *rtl, "tb/main_memory.v", "tb/tb_workload.sv",
        ])
        for name, transactions in workloads():
            rows = reference(transactions, ways)
            trace = build / f"{design}-{name}.txt"
            trace.write_text("".join(
                f"{s} {a:08x} {d:08x} {h} {v:08x} {w} {va:08x} {vd:08x}\n"
                for s, a, d, h, v, w, va, vd in rows
            ))
            output = run(shlex.split(args.vvp) + [str(executable), f"+TRACE={trace}"])
            match = re.search(r"RESULT (\d+) (\d+) (\d+) (\d+) (\d+)", output)
            if not match:
                raise RuntimeError(output)
            count, hits, misses, writebacks, cycles = map(int, match.groups())
            assert count == COUNT
            assert hits == sum(row[3] for row in rows)
            assert writebacks == sum(row[5] for row in rows)
            records.append(dict(
                design=design, workload=name, accesses=count, hits=hits,
                misses=misses, writebacks=writebacks, response_cycles=cycles,
                miss_rate=round(misses / count, 8),
                average_response_cycles=round(cycles / count, 8),
            ))
            logs.append(f"{design}/{name}\n{output}")
            print(f"{design:14} {name:18} misses={misses:4} "
                  f"writebacks={writebacks:3} cycles/access={cycles/count:.4f}")
    labels = ["Sequential fit", "Sequential stream", "Stride 16", "Conflict pair",
              "Conflict triple", "Random hot", "Random wide", "Mixed writes"]
    table = []
    for label, direct, two_way in zip(labels, records[:8], records[8:]):
        table.append(
            f"{label} & {direct['misses']} & {two_way['misses']} & "
            f"{direct['average_response_cycles']:.3f} & "
            f"{two_way['average_response_cycles']:.3f} " + chr(92) * 2
        )
    (results_dir / "report-table.tex").write_text("\n".join(table) + "\n")
    with (results_dir / "benchmarks.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=records[0].keys())
        writer.writeheader()
        writer.writerows(records)
    (results_dir / "simulation.log").write_text("\n".join(logs))
    metadata = dict(
        random_seed=SEED, accesses_per_workload=COUNT, workloads=8,
        checked_transactions=len(records)*COUNT,
        timing="Acceptance rising edge to response rising edge; excludes idle gaps",
        latency_formula="1 + 3*miss + 3*dirty_writeback",
        simulator=run(shlex.split(args.iverilog) + ["-V"]).splitlines()[0],
    )
    (results_dir / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")


if __name__ == "__main__":
    main()
