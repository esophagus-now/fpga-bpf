`timescale 1ns / 1ps
/*
fakedata.v

Essentially just generates some test data for me to see if the design actually
works in hardware.

This file causes two ROMs to be synthesized, and their contents are loaded from
some .mem files in this directory.
*/


module fakedata(
    input clk,
    input rst,
    output reg [31:0] data = 0,
    output reg strobe = 0,
    output reg last = 0
);

reg [31:0] testdata [0:63];
reg teststrobe [0:63];
reg testlast [0:63];

initial begin
	//I really hope this synthesizes correctly!!!!
	$readmemh("testdata.mem", testdata);
	$readmemb("teststrobe.mem", teststrobe);
	$readmemb("testlast.mem", testlast);
end

reg [7:0] addr = 0;

wire [7:0] nextaddr;
assign nextaddr = addr + 1; //Overflow is the desired behaviour

wire [7:0] clamped_addr;
assign clamped_addr = (addr < 8'd64) ? addr : 8'd63;

always @(posedge clk) begin
	if (!rst) begin
		addr <= nextaddr;
		data <= testdata[clamped_addr];
		strobe <= teststrobe[clamped_addr];
		last <= testlast[clamped_addr];
	end
		
end

endmodule
