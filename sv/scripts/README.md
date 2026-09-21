# Native SystemVerilog build tools

The maintained build starts from the checked-in SystemVerilog and frozen reference
HDL. It does not invoke project Python, PyMTL, or a reference generator. Verilator
can invoke its own Python helper while compiling its generated C++ model.

From PowerShell, run the following from the worktree root (change tool paths for
the host). An absolute path to `run.ps1` works from any other directory:

```powershell
& ./sv/scripts/run.ps1 -Task probe `
  -OssCadSuite D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite `
  -Sv2v D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe
```

Use `-Task types` for independent type packing checks, `-Task sim` for the
native/reference test, `-Task negative` for its deliberately incorrect expectation,
`-Task timeout-negative` for permanently blocked output, and `-Task synth` for
synthesis/check. `-Task all` runs all five design targets.
Optional `-Liberty <NangateOpenCellLibrary_typical.lib>` also
runs standard-cell mapping and area reporting. `-Jobs` limits C++ compilation
parallelism (default 2). `OSS_CAD_SUITE` and `SV2V` environment variables can replace
the corresponding arguments. `-MsysRoot` defaults to `C:/msys64`.

On a Unix host with the tools on PATH, the corresponding entry is `make -C sv
probe`, `make -C sv all`, or `make -C sv synth LIBERTY=/path/to/library.lib`.
`VERILATOR`, `SV2V`, `YOSYS`, `CXX`, `COMPILER`, and `JOBS` are overridable Make
variables. The Windows wrapper uses the same Makefile, plus the tested host
adaptations below. The Unix entry has not been executed in this Windows session.

The file lists separate synthesis from verification. `filelists/rtl.f` contains
only the native DUT. `filelists/sim.f` adds the original frozen reference and SV
testbench. The simulation receives an absolute `+VECTORS` path, so execution does
not depend on the calling directory. Generated files and logs stay under
`sv/build/`. Successful simulation requires a `CGRA_2X2_PASS` marker; `$fatal`
failures and timeouts propagate a nonzero exit. The negative target requires both
nonzero exit and its designated failure message.

## Validated local tool combination

- UCRT MSYS2 Verilator 5.050 (`C:/msys64/ucrt64/bin/verilator`).
- Clang64 clang++ 22.1.8 and its matching C++ runtime.
- MSYS2 GNU Make 4.4.1, Bash and Perl.
- sv2v 0.0.13 and OSS CAD Yosys 0.69+62.

The installed GCC 16.1.0 configuration failed at final link with missing
`std::__cxx11::basic_string` symbols, including when static libstdc++ was requested.
The selected clang path compiled and ran the probe. The UCRT Verilator model's
configured link libraries include `-latomic`, which the Clang64 environment does
not provide; the Windows wrapper therefore selects `LDLIBS=-pthread`. The link
command clears the exported `LINK` environment variable because Windows clang/lld
otherwise interprets its value as an extra linker input. The wrapper also places
the OSS CAD runtime DLL directory before other tool runtime directories for Yosys.
No installed tool files are changed.

The probe exercises packages, a type parameter, packed structures, unpacked array
ports, a clocked ready/valid stage, held data under backpressure, clock delays, and
a deliberately failing test. Its RTL is converted with sv2v and synthesized with
Yosys, including `hierarchy -check` and `check -assert`. A separate initial
`read_slang` synthesis probe passed, but the maintained flow uses sv2v followed by
the Verilog frontend. Icarus 14.0 rejected the named assignment patterns in the
probe TB; it is not the selected simulation path.

The fixed generated core/reference emit width and UNOPTFLAT warnings in Verilator.
The full-design simulation adds `-Wno-fatal`, retaining these warnings in
`build/sim/verilate.log`. It does not suppress the warning text, remove logic, or
relax testbench comparisons. Syntax errors, runtime convergence errors, checker
failures, and timeouts still fail the build. Probe and type tests keep the default
fatal-warning behavior (except irrelevant missing-timescale warnings).

Synthesis first writes a generic mapped hierarchy and JSON statistics, then
optionally maps that same intermediate netlist to Nangate cells. The optional ABC
constraints are BUF_X1 driving cells and 5.0 fF output loads. Final mapped checking
loads the Liberty cell models before `check -mapped -assert`. This stage reports
area and structural validity, not a timing/frequency qualification. Unknowns are
not replaced by constants by this build script.
