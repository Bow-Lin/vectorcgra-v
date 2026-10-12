`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module tile_streaming #(`CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS) (

  `include "cgra_pe_ports.svh"
);
  tile_variant_core #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND, .STREAMING(1)) core (.*);
endmodule
