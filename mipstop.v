// Top level system including MIPS and memories

module top(input clk, reset,
output logic [31:0] writedata, dataadr,
output logic memwrite);

  wire [31:0] pc, instr, readdata;
  
  // processor and memories are instantiated here 
  mips mips(clk, reset, pc, instr, memwrite, dataadr, writedata, readdata);
  imem imem(pc[7:2], instr);
  dmem dmem(clk, memwrite, dataadr, writedata, readdata);

endmodule
