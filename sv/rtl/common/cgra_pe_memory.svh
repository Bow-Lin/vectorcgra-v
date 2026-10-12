// Static attachment of one memory FU, or explicit zeros for a catalog without it.
// Requires PE_MEMORY_KIND and the common element__/public PE signal names.
// No sequential state and no include guard.
  function automatic int memory_count();
    int count;
    count=0;
    for(int i=0;i<FU_COUNT;i++) if(FU_KINDS[8*i+:8]==PE_MEMORY_KIND) count++;
    return count;
  endfunction
  initial if(memory_count()>1) $fatal(1,"Only one attached memory FU is supported");
  if(memory_count()==0) begin : no_memory_fu
    assign to_mem_raddr__msg='0;
    assign to_mem_raddr__val=1'b0;
    assign to_mem_waddr__msg='0;
    assign to_mem_waddr__val=1'b0;
    assign to_mem_wdata__msg='0;
    assign to_mem_wdata__val=1'b0;
    assign from_mem_rdata__rdy=1'b0;
  end
  for(genvar slot=0;slot<FU_COUNT;slot++) begin : memory_slots
    initial if((FU_KINDS[8*slot+:8]==`CGRA_FU_MEM ||
                FU_KINDS[8*slot+:8]==`CGRA_FU_STREAMING_MEM) &&
               FU_KINDS[8*slot+:8]!=PE_MEMORY_KIND)
      $fatal(1,"PE_MEMORY_VARIANT: memory FU kind does not match the PE variant");
    if(FU_KINDS[8*slot+:8]==PE_MEMORY_KIND) begin : attached
      assign to_mem_raddr__msg=element__to_mem_raddr__msg[slot];
      assign to_mem_raddr__val=element__to_mem_raddr__val[slot];
      assign element__to_mem_raddr__rdy[slot]=to_mem_raddr__rdy;
      assign to_mem_waddr__msg=element__to_mem_waddr__msg[slot];
      assign to_mem_waddr__val=element__to_mem_waddr__val[slot];
      assign element__to_mem_waddr__rdy[slot]=to_mem_waddr__rdy;
      assign to_mem_wdata__msg=element__to_mem_wdata__msg[slot];
      assign to_mem_wdata__val=element__to_mem_wdata__val[slot];
      assign element__to_mem_wdata__rdy[slot]=to_mem_wdata__rdy;
      assign element__from_mem_rdata__msg[slot]=from_mem_rdata__msg;
      assign element__from_mem_rdata__val[slot]=from_mem_rdata__val;
      assign from_mem_rdata__rdy=element__from_mem_rdata__rdy[slot];
    end else begin : detached
      assign element__to_mem_raddr__rdy[slot]=1'b0;
      assign element__to_mem_waddr__rdy[slot]=1'b0;
      assign element__to_mem_wdata__rdy[slot]=1'b0;
      assign element__from_mem_rdata__msg[slot]='0;
      assign element__from_mem_rdata__val[slot]=1'b0;
    end
  end
