`timescale 1ns / 1ps
/*
fakedatatb.sv

Runs an extremely simple test to make sure that fakedata.v works (before I
go to the trouble of putting it on the FPGA). In particular, this lets me
test if the design synthesizes the way I think it will
*/


module fakedatatb();

reg clk;
reg rst;
wire [31:0] data;
wire strobe;

initial begin
	clk <= 0;
	rst <= 1;
	
	repeat (10) @(negedge clk);
	
	rst <= 0;
end

always #5 clk <= ~clk;

fakedata DUT (
	.*
);

endmodule
