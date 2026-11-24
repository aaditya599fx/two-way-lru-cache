#!/usr/bin/env python3
"""Render measured benchmark results for the report. Requires matplotlib."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
with (ROOT / "results/benchmarks.csv").open() as stream:
    rows = list(csv.DictReader(stream))
names = [row["workload"] for row in rows if row["design"] == "direct_mapped"]
labels = ["Fit", "Stream", "Stride", "Pair", "Triple", "Hot", "Wide", "Writes"]
fig, axes = plt.subplots(2, 1, figsize=(8, 5.6), sharex=True)
colors = ["#315d94", "#cf6b27"]
for offset, design in enumerate(["direct_mapped", "two_way_lru"]):
    values = {row["workload"]: row for row in rows if row["design"] == design}
    x = [i + (offset - 0.5) * 0.36 for i in range(len(names))]
    label = "Direct mapped" if offset == 0 else "Two-way LRU"
    axes[0].bar(x, [100*float(values[n]["miss_rate"]) for n in names],
                width=0.36, color=colors[offset], label=label)
    axes[1].bar(x, [float(values[n]["average_response_cycles"]) for n in names],
                width=0.36, color=colors[offset])
axes[0].set_ylabel("Miss rate (%)")
axes[0].set_ylim(0, 115)
axes[0].legend(frameon=False, ncol=2, loc="upper center")
axes[1].set_ylabel("Response cycles / access")
axes[1].set_ylim(0, 4.5)
axes[1].set_xticks(range(len(names)), labels)
for axis in axes:
    axis.spines[["top", "right"]].set_visible(False)
    axis.grid(axis="y", alpha=0.18)
    axis.set_axisbelow(True)
fig.tight_layout()
fig.savefig(ROOT / "results/comparison.png", dpi=220)
plt.close(fig)
