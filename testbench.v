module testbench();
reg clk;
reg reset = 1;
// instantiate device to be tested
top dut (clk, reset);
//initialize test
initial begin
    #2;
    reset <= ~reset;
  end
// generate clock to sequence tests
initial begin
    forever begin
      clk <= ~clk;
      #5;
    end
  end
// check results
always @(negedge clk)
begin
    // #100
    // $stop;
if (memwrite) begin
if (dataadr === 84 & writedata === 7) begin
$display("Simulation succeeded");
$stop;
end else if (dataadr !== 80) begin
$display("Simulation failed");
$stop;
end
end
end
endmodule