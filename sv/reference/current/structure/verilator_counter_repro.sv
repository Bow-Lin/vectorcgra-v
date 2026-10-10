module tb;
// Default build reproduces 5.029's false constant folding; +define+KEEP_COUNTERS
// uses the same workaround as the current migration replay benches.
`ifdef KEEP_COUNTERS
integer a /* verilator public_flat_rw */;
integer b /* verilator public_flat_rw */;
integer c /* verilator public_flat_rw */;
`else
integer a,b,c;
`endif
integer i,fd,rc;
initial begin
 a=0;b=0;c=0;
 fd=$fopen("reference/current/migration/global_add/cycles.txt","r");
 while(!$feof(fd))begin
   logic [4095:0] x,y;
   rc=$fscanf(fd,"%h %h\n",x,y);
   a++;if(a<=6)b++;if(a<=2)c++;
   #1;
 end
 $display("a=%0d b=%0d c=%0d",a,b,c);
 if(a!=91 || b!=6 || c!=2)$fatal(1,"wrong");
 $display("PASS");$finish;
end
endmodule
