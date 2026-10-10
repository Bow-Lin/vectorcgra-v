// Constant data only, shared by simulation and synthesis wrappers.
function automatic logic [DATA_BITS-1:0] fixture_word(input integer i);
  if (ORIGINAL) return DATA_BITS'((i<<3)|4);
  return (DATA_BITS'(1) << (DATA_BITS-1)) | DATA_BITS'(32'h12345+i*32'h913);
endfunction
function automatic logic [DEPTH*DATA_BITS-1:0] fixture_rom();
  logic [DEPTH*DATA_BITS-1:0] result;
  for (integer i=0;i<DEPTH;i++) result[i*DATA_BITS +: DATA_BITS]=fixture_word(i);
  return result;
endfunction
localparam logic [DEPTH*DATA_BITS-1:0] WORDS=fixture_rom();
