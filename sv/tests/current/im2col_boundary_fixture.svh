function automatic logic [SCRATCH_DEPTH*DATA_W-1:0] make_image();
  logic [SCRATCH_DEPTH*DATA_W-1:0] result;
  result='0;
  for(integer i=0;i<25;i++) result[i*DATA_W+:DATA_W]=DATA_W'((i*17+3)^((i%7==0)?32'h80000000:32'd0)) | (DATA_W==64?(DATA_W'(i)<<40):DATA_W'(0));
  return result;
endfunction
localparam logic [SCRATCH_DEPTH*DATA_W-1:0] IMAGE=make_image();
