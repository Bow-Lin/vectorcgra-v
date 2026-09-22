# 64-Tile validation profile

Four CGRAs each contain 4x4 Tiles. The native SV bench builds two fresh programs,
compares every raw host output bit each cycle with the frozen unmodified ac96
HDL, and independently checks results, memory ownership, completions, ordering,
backpressure and reset. CHECK_PYTHON is explicitly false for this profile.

The optional original Python cycle simulation was stopped after 4178 seconds
without completing its first scenario. Its full translated HDL, original
exporter snapshot and source manifest remain unchanged. See the reference
python-trace-status.json. program0.hex is the complete configuration assembled
before simulation; it is not a completed Python trace and is not used as the
runtime input. The other three system profiles retain Python three-way checks.

For a fresh future export, phase4_multi_export.py --tiles 4 --hdl-only avoids
this optional long simulation. Normal SV tests do not run that Python script.
