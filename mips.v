// single-cycle MIPS processor
// instantiates a controller and a datapath module

module mips(input          clk, reset,
            output  [31:0] pc,
            input   [31:0] instr,
            output         memwrite,
            output  [31:0] aluout, writedata,
            input   [31:0] readdata);

  wire        memtoreg, branch,
               pcsrc, zero,
               alusrc, regdst, regwrite, jump;
  wire [2:0]  alucontrol;

  controller c(instr[31:26], instr[5:0], zero,
               memtoreg, memwrite, pcsrc,
               alusrc, regdst, regwrite, jump,
               alucontrol);
  datapath dp(clk, reset, memtoreg, pcsrc,
              alusrc, regdst, regwrite, jump,
              alucontrol,
              zero, pc, instr,
              aluout, writedata, readdata);
endmodule


// Todo: Implement controller module
module controller(input   [5:0] op, funct,
                  input         zero,
                  output        memtoreg, memwrite,
                  output        pcsrc, alusrc,
                  output        regdst, regwrite,
                  output        jump,
                  output  [2:0] alucontrol);
wire [1:0] aluop;
wire branch;
wire bne;
maindec md(op, memtoreg, memwrite, branch,
alusrc, regdst, regwrite, jump, aluop);
aludec ad(funct, aluop, alucontrol);
// using the difference between bne and beq to determine weather we need to use this mux or not to change when beq is used
mux2 #(1) bnemux(zero, ~zero, op[0], bne);
assign pcsrc = branch & bne;


endmodule


// Todo: Implement datapath
module datapath(input          clk, reset,
                input          memtoreg, pcsrc,
                input          alusrc, regdst,
                input          regwrite, jump,
                input   [2:0]  alucontrol,
                output         zero,
                output  [31:0] pc,
                input   [31:0] instr,
                output  [31:0] aluout, writedata,
                input   [31:0] readdata);
wire [4:0] writereg;
wire [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
wire [31:0] signimm, signimmsh;
wire [31:0] srca, srcb, oriext;
wire [31:0] result;
// next PC logic
flopr #(32) pcreg(clk, reset, pcnext, pc);
adder pcadd1(pc, 32'b100, pcplus4);
sl2 immsh(signimm, signimmsh);
adder pcadd2(pcplus4, signimmsh, pcbranch);
mux2 #(32) pcbrmux(pcplus4, pcbranch, pcsrc, pcnextbr);
mux2 #(32) pcmux(pcnextbr, {pcplus4[31:28],
instr[25:0], 2'b00}, jump, pcnext);
// register file logic
regfile rf(clk, regwrite, instr[25:21], instr[20:16],
writereg, result, srca, writedata);
mux2 #(5) wrmux(instr[20:16], instr[15:11],
regdst, writereg);
mux2 #(32) resmux(aluout, readdata, memtoreg, result);
signext se(instr[15:0], signimm);
// ALU logic
mux2 #(32) srcbmux(writedata, signimm, alusrc, srcb);
//we need to use one more mux before we input into the alu to make sure our ori affects the proper inputs
zeroextend oriextend(instr[15:0], alucontrol, srcb, oriext);
alu alu(srca, oriext, alucontrol, aluout, zero);              
endmodule

module regfile(input  clk,
input  we3,
input  [4:0] ra1, ra2, wa3,
input  [31:0] wd3,
output  [31:0] rd1, rd2);
reg [31:0] rf[31:0];
// three ported register file
// read two ports combinationally
// write third port on rising edge of clk
// register 0 hardwired to 0
// note: for pipelined processor, write third port
// on falling edge of clk
always @(posedge clk)
if (we3) rf[wa3] <= wd3;
assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule

module maindec(input  [5:0] op,
output  memtoreg, memwrite,
output  branch, alusrc,
output  regdst, regwrite,
output  jump,
output  [1:0] aluop);
reg [8:0] controls;
assign {regwrite, regdst, alusrc, branch, memwrite,
memtoreg, jump, aluop} = controls;
always @*
case(op)
6'b000000: controls <= 9'b110000010; // RTYPE
6'b100011: controls <= 9'b101001000; // LW
6'b101011: controls <= 9'b001010000; // SW
6'b000100: controls <= 9'b000100001; // BEQ
6'b001000: controls <= 9'b101000000; // ADDI
6'b000010: controls <= 9'b000000100; // J
6'b001101: controls <= 9'b101000011; //ori ADDED FOR LAB 4
6'b000101: controls <= 9'b000100001; //bne ADDED FOR LAB 4
default: controls <= 9'bxxxxxxxxx; // illegal op
endcase
endmodule

module aludec(input  [5:0] funct,
input  [1:0] aluop,
output reg [2:0] alucontrol);
always @*
case(aluop)
2'b00: alucontrol <= 3'b010; // add (for lw/sw/addi)
2'b01: alucontrol <= 3'b110; // sub (for beq)
2'b11: alucontrol <= 3'b001; // or (for ori) ADDED FOR LAB 4
default: case(funct) // R-type instructions
6'b100000: alucontrol <= 3'b010; // add
6'b100010: alucontrol <= 3'b110; // sub
6'b100100: alucontrol <= 3'b000; // and
6'b100101: alucontrol <= 3'b001; // or
6'b101010: alucontrol <= 3'b111; // slt
default: alucontrol <= 3'bxxx; // ???
endcase
endcase
endmodule

module adder(input  [31:0] a, b,
output  [31:0] y);
assign y = a + b;
endmodule

module sl2(input  [31:0] a,
output  [31:0] y);
// shift left by 2
assign y = {a[29:0], 2'b00};
endmodule

module signext(input  [15:0] a,
output  [31:0] y);
assign y = {{16{a[15]}}, a};
endmodule

module flopr #(parameter WIDTH = 8)
(input  clk, reset,
input  [WIDTH-1:0] d,
output reg [WIDTH-1:0] q);
always @(posedge clk, posedge reset)
if (reset) q <= 0;
else q <= d;
endmodule

module mux2 #(parameter WIDTH = 8)
(input  [WIDTH-1:0] d0, d1,
input  s,
output  [WIDTH-1:0] y);
assign y = s ? d1 : d0;
endmodule

//We combine the zero extend and the mux, if aluop is 11 then output zeroextend else output srcb
module zeroextend(input [15:0]a,
                input [2:0]alucontrol,
                input [31:0]srcb,
                output [31:0]b);
    assign b = (alucontrol == 3'b001) ? {{16{1'b0}}, a} : {srcb};
endmodule