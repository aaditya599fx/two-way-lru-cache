#!/usr/bin/env python3
# FILE PURPOSE: draws the comparison graph from the saved results.
# A short description of this file.
"""Render measured benchmark results for the report. Requires matplotlib."""
# Tool for reading CSV files.
import csv
# Tool for handling file paths.
from pathlib import Path
# The main graph library (it must be installed).
import matplotlib
# Draw straight to a file, without opening a window.
matplotlib.use("Agg")
# The part of the library that makes plots.
import matplotlib.pyplot as plt

# ROOT = the main project folder.
ROOT = Path(__file__).resolve().parents[1]
# Open the results CSV file.
with (ROOT / "results/benchmarks.csv").open() as stream:
    # Read all its rows into a list.
    rows = list(csv.DictReader(stream))
# Get the pattern names (taken from the direct-mapped rows, so each appears once).
names = [row["workload"] for row in rows if row["design"] == "direct_mapped"]
# Short names to show under the bars.
labels = ["Fit", "Stream", "Stride", "Pair", "Triple", "Hot", "Wide", "Writes"]
# Make 2 graphs, one above the other, sharing the same bottom axis.
fig, axes = plt.subplots(2, 1, figsize=(8, 5.6), sharex=True)
# Blue for direct-mapped, orange for two-way.
colors = ["#315d94", "#cf6b27"]
# Draw the bars for each of the two designs.
for offset, design in enumerate(["direct_mapped", "two_way_lru"]):
    # Get this design's results, arranged by pattern name.
    values = {row["workload"]: row for row in rows if row["design"] == design}
    # Bar positions: one design slightly left, the other slightly right.
    x = [i + (offset - 0.5) * 0.36 for i in range(len(names))]
    # The name shown in the legend.
    label = "Direct mapped" if offset == 0 else "Two-way LRU"
    # Top graph: miss rate as a percentage.
    axes[0].bar(x, [100*float(values[n]["miss_rate"]) for n in names],
                # Set the bar width, colour and name.
                width=0.36, color=colors[offset], label=label)
    # Bottom graph: average cycles per access.
    axes[1].bar(x, [float(values[n]["average_response_cycles"]) for n in names],
                # Set the bar width and colour.
                width=0.36, color=colors[offset])
# Label the side of the top graph.
axes[0].set_ylabel("Miss rate (%)")
# Set its height range, leaving space for the legend.
axes[0].set_ylim(0, 115)
# Show the legend (which colour is which).
axes[0].legend(frameon=False, ncol=2, loc="upper center")
# Label the side of the bottom graph.
axes[1].set_ylabel("Response cycles / access")
# Set its height range.
axes[1].set_ylim(0, 4.5)
# Put the pattern names under the bars.
axes[1].set_xticks(range(len(names)), labels)
# Style both graphs.
for axis in axes:
    # Hide the top and right border lines.
    axis.spines[["top", "right"]].set_visible(False)
    # Add light horizontal grid lines.
    axis.grid(axis="y", alpha=0.18)
    # Draw the grid behind the bars.
    axis.set_axisbelow(True)
# Adjust the spacing so nothing overlaps.
fig.tight_layout()
# Save the picture as results/comparison.png.
fig.savefig(ROOT / "results/comparison.png", dpi=220)
# Close the figure to free memory.
plt.close(fig)
