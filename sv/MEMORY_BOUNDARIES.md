# Memory and peripheral boundaries

Target Python is `cd7aad878915e389cecf8cc01ff6987d156bd019`. The original
274 source files remain unchanged. `reference/current/memory_boundaries/`
records source behavior separately from native transaction and image math.

## Native contracts

| Interface | Native behavior | Explicit source compatibility |
|---|---|---|
| `cgra_data_memory` | A local write accepts its address and data together. A missing half cannot cause a write or acknowledge the valid half. Reset suppresses public handshakes and cancels bank writes still queued at the reset edge. Committed SRAM contents persist. The optional 32-bit DMA port accepts full-word masks only and zero-extends its data into wider SRAM words. | `MEMORY_LEGACY_PYTHON=1` preserves address-only validity and source reset behavior; forwarded through the shared profile. |
| `cgra_dma_engine` | SPM words are 32 bits. Commands 0/1 mean MVIN/MVOUT; byte count must be a multiple of four, including zero. DRAM addresses advance in bytes; SPM addresses advance in words. Tail beat masks cover exactly the remaining words. Reset suppresses requests, response readiness and completion and permits a fresh command after reset. | `LEGACY_PYTHON=1` retains truncated byte counts, sub-word underflow, nonzero-opcode MVOUT and reset handshakes. `BASELINE_TRANSLATED_SLICES` is an independent historical HDL defect switch. |
| `cgra_im2col_engine` | Private image storage uses `cgra_data_mem`. DONE holds completion but accepts configuration or another launch. Reset cancels work and clears geometry/destination. A dimension equal to the entire scratch depth remains representable. Image and kernel dimensions must be positive; the image fits scratch storage, the kernel fits the image, stride exponent is at most the scratch address width, and the full output span fits global address space. | `LEGACY_PYTHON=1` retains terminal DONE, geometry surviving reset, narrow dimensions and the original private lazy-preload memory. |
| `cgra_integrated_im2col` | A host-accepted launch blocks subsequent host requests until engine completion. A pending launch is tracked through controller buffering, so a previous DONE cannot release the next launch prematurely. | `PERIPHERAL_LEGACY_PYTHON=1` retains the old downstream launch gate and engine behavior. |

Invalid native DMA/im2col commands deassert ready, remain unaccepted and have no
transaction effects. RTL simulation also reports the named command error at the
clock edge. Synthesized hardware retains the rejection logic; `$fatal` is not an
error-reporting hardware interface. Clients must issue valid commands.

DMA reset is a **global endpoint flush** contract: the engine and the responding
DRAM/SPM endpoint discard outstanding responses together. The interface has no
response transaction ID or epoch. It cannot distinguish a late pre-reset response
from a new response, and it cannot undo writes already accepted by an endpoint.
Payload bits need not be zero while DMA valid is low. Zero-byte DMA still returns
one held completion with its tag and makes no memory request.

An im2col completion means that its final store packet was accepted by the
controller. It is not a general memory fence against concurrent PE/NoC writers.
The integrated readback tests keep PE traffic quiescent; overlapping accesses
require software coordination. DMA also retains fixed-width address arithmetic:
software must keep each transfer within its mapped DRAM/SPM address range.

im2col retains the source's output ordering: kernel row, kernel column, window
row, window column. Output packets contain CMD_STORE_REQUEST, pixel metadata
`predicate=1,bypass=0,delay=0`, and contiguous destination word addresses. Scratch
preload word zero occupies the low parameter bits. There is no image-write or
image-DMA API in the original engine; this work does not invent one. Native reset
restores that private image's logical preload state. This differs from the banked
shared SRAM, whose committed contents persist across reset. Unwritten shared
SRAM locations have no portable initialization value; transaction tests write
every location before checking its contents.

## Source limitations, kept visible

| Original controller configuration | Pure Python | Original HDL translation | Validation used |
|---|---|---|---|
| 3 reads / 1 write | Passes | Fails: `trunc` tries to widen a one-bit write source to a two-bit remote source | Raw pure-Python replay plus independent native local/NoC math |
| 1 read / 3 writes | Fails: write port index 2 overflows `Bits1` | Passes | Fresh original HDL comparison plus independent native local/NoC math |

These are different failures. Successful HDL translation is not successful
pure-Python simulation, and a native math pass is not cycle equivalence to either.
The probe records both stages without modifying the source. Compatibility modes
are diagnostic contracts, not the default design recommendations.

Tests establish state with a reset edge before comparing DMA/controller FSM
outputs. Power-on values before reset are not a portable hardware contract:
Yosys may recode the DMA FSM from binary to one-hot. After initialization every
sampled output bit is compared, including invalid and reset cycles. Raw random
traffic is used only for source behavior comparison; independent protocol-valid
scoreboards establish native transfer correctness.

## Acceptance

Run `make current-memory-boundaries` and `make current-memory-boundaries-synth`.
The normal HDL runners consume SV, frozen vectors and frozen reference HDL only;
they do not import project Python or PyMTL.

Coverage includes:

- Unchanged original im2col, DMA and DataMemController tests; independently
  regenerated raw source traces and the asymmetric translation probe.
- DMA DRAM widths 32, 96, 128 and 256, both directions, every tail mask, zero
  length, output/completion backpressure, eight public reset boundaries and
  invalid-command rejection. Both RTL and actual emitted netlists run the same
  transaction scoreboard and deliberately wrong expectations must fail.
- im2col DATA_W 32/64, scratch depths 64/32/30, repeated launch, stride,
  full-depth dimensions, busy configuration, held output, reset/reconfiguration,
  destination last-word boundary and invalid geometry/span rejection. Raw legacy
  traces cover warm configuration, abort and terminal DONE.
- Banked memory asymmetric read/write counts, 32/64-bit metadata-bearing words,
  combinational/registered channels, delayed write halves, contention, held
  read-before-write snapshots, reset retention/cancellation, incoming/outgoing
  NoC reads and controller DMA access.
- Integrated CPU launch immediately followed by SRAM reads, repeated im2col
  commands, reset during execution and final readback; integrated DMA 128/256-bit
  DRAM round trips through shared SPM.
- `sv2v` conversion, Yosys synthesis, structural checks and zero combinational
  SCCs on emitted netlists, followed by fresh netlist simulation. `splitnets`
  exposes independent bits to downstream tools; convergence limits and RTL
  optimization are not relaxed to hide loops.

The integrated single-CGRA configuration also explicitly grounds its unused
external NoC outputs; the original undriven ports failed structural checking.
The full-system netlist retains Yosys primitive cells (`write_verilog -noexpr`),
reimports them with `read_verilog -icells`, and simulates with the installed
Yosys `simcells.v` models. Private net names are shortened; public ports remain
unchanged. This avoids re-inferring every flip-flop during netlist validation.
Its RTL still reports coarse procedural `UNOPTFLAT` dependencies. The emitted
complete-system netlist is checked for real SCCs and reruns the public CPU/SRAM
scoreboard; RTL diagnostics are recorded rather than suppressed.

Exact parameters, counts, source hashes, tool versions, logs and netlist hashes
are recorded in `reference/current/memory_boundaries/validation.json`. No result
here establishes arbitrary NoC arbitration/VC behavior; the following NoC task
owns those remaining shared-fabric handshake and structural checks. Larger DMA
formats and general run-time isolation remain outside this migration scope.
