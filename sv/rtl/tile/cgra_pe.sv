// Configurable single PE. VARIANT: 0=base, 1=context switch, 2=streaming.
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module cgra_pe #(
  `CGRA_PROFILE_PARAMETERS,
  `CGRA_FU_PARAMETERS,
  parameter int VARIANT = 0
) (

  `include "cgra_pe_ports.svh"
);
  initial begin
    if (VARIANT < 0 || VARIANT > 2) $fatal(1,"cgra_pe VARIANT must be 0, 1 or 2");
    if (CTRL_DEPTH < 2 || REG_DEPTH < 2 || NUM_CTRL < 1 || NUM_CTRL > CTRL_DEPTH)
      $fatal(1,"cgra_pe requires storage depths >=2 and 1 <= NUM_CTRL <= CTRL_DEPTH");
    if (TILE_PORTS != 4 && TILE_PORTS != 8) $fatal(1,"cgra_pe requires 4 or 8 ports");
    if (VARIANT == 2 && TILE_PORTS != 8) $fatal(1,"streaming PE requires 8 ports");
  end
  if (VARIANT == 0) begin : base
    tile_programmable #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) core (.*);
  end else if (VARIANT == 1) begin : context_switch
    tile_context #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) core (.*);
  end else begin : streaming
    tile_streaming #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) core (.*);
  end
endmodule
