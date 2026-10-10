// Fixed fixture data shared by the RTL and synthesis wrappers, never state logic.
function automatic logic [DATA_BITS-1:0] fixture_word(input integer i);
  logic [DATA_BITS-4:0] payload;
  if (ORIGINAL) return DATA_BITS'(((9-i)<<3) | 4);
  payload=(1 << (DATA_BITS-4)) | (32'h13579+i*32'h2468);
  return {payload,1'(i&1),1'((i>>1)&1),1'((i^1)&1)};
endfunction
function automatic logic [((NUM_CONST>0)?NUM_CONST:1)*DATA_BITS-1:0] fixture_rom();
  logic [((NUM_CONST>0)?NUM_CONST:1)*DATA_BITS-1:0] result;
  result='0;
  for (integer i=0;i<NUM_CONST;i++) result[i*DATA_BITS +: DATA_BITS]=fixture_word(i);
  return result;
endfunction
localparam logic [((NUM_CONST>0)?NUM_CONST:1)*DATA_BITS-1:0] WORDS=fixture_rom();
