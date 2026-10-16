# Frozen historical golden RTL

`cgra_2x2_core.sv` is the unchanged namespaced golden implementation formerly at
`rtl/fixed/cgra_2x2_core.sv`. It is only used by differential tests. It is not a
native system top and is not compiled by `filelists/native.f`.

The original namespace transformation and source hash remain recorded in
`../core_provenance.json`. Its historical target path is resolved by
`../../tests/legacy/relocations.json`; the golden HDL bytes are unchanged.
