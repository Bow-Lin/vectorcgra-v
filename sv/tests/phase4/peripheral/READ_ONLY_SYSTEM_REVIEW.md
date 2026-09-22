# Independent composition review

Reviewer: `/root/synth_tools`, 2026-09-22. This review does not modify shared
RTL. It supplements the peripheral integration tests; it is not a formal
proof of all parameter combinations.

Reviewed `cgra_system.sv`, `cgra_multi.sv`, `cgra_multi_template.sv` against
ac96 `CgraTemplateRTL.py`, `RingMultiCgraRTL.py`, and
`MeshMultiCgraTemplateRTL.py`.

For full rectangular Tile profiles, no additional wiring issue was found:

- Control-ring capacity uses MAX_TILES+1; the controller attaches at local
  NUM_TILES and unused later routers are grounded. This matches original
  CgraTemplateRTL's local controller position in the maximum-sized ring.
- Inter-CGRA packet destination X/Y offsets include payload, two VC bits,
  eight opaque bits, remote port and both Tile IDs. Ring destination ID
  selects the field immediately below source ID. Control-ring VC remains
  one bit. These offsets agree with the packed profile types.
- CPU attaches only to CGRA0. Other host inputs are grounded and their
  output ready is zero, as in the original.
- Physical boundary traffic remains a non-wrapping rectangular mesh even
  when packet NoC is a ring. This matches original RingMultiCgraRTL.
- Heterogeneous boundary links use the overlapping row/column extent and
  ground the remainder; lower/upper neighbor orientation matches the
  original Cartesian row-major CGRA numbering.
- Custom links select a source/destination physical port without changing
  ready/valid timing. Guards reject duplicate links or overlap with a
  boundary mapping. Separate read/write memory tables preserve memory
  channel connectivity independently of generic routing data ports.

Two scope issues were sent to the parent:

1. Multi wrappers passed HAS_DMA/HAS_IM2COL to child systems while tying all
   peripheral ports inactive. Such enabled configurations would block
   forever on peripheral commands. Parent confirmed adding guards to
   reject these flags on the multi wrappers; integrated peripheral wrappers
   remain the supported connection points.
2. Original CgraTemplateRTL obtains entity count from len(TileList), while
   native cgra_system fixes it to COLS*ROWS. The reviewed implementation
   therefore represents complete rectangular Tile lists plus custom links,
   per-Tile FUs and heterogeneous rectangular shapes. Sparse/disabled Tile
   lists have not been demonstrated equivalent. Original getIndex skips
   disabled objects while CgraTemplate instantiates len(TileList), so that
   original domain itself requires a dedicated reference experiment before
   making support claims. No sparse-list execution was performed here.

Parent is extending independent memory write-port counts after this review.
Final frozen-source regressions and parameter guards should be assessed
against the parent's final source hashes. The ongoing peripheral system
runs used the default equal read/write-port counts.
