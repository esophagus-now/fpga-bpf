`timescale 1ns / 1ps
/*
dataval_snooper.v

A simple snooper for data + valid wires. This can be used with AXI stream if the
boolean AND of valid and ready is used for the "strobe" input to this module. If
you just have simple data + valid, then you may want to apply a one-shot multi-
vibrator on your valid line. A simple parameter controls the number of flits per 
packet
*/


module dataval_snooper # (parameter
	FLITS_PER_PACKET = 10,
	DATA_WIDTH = 32,
	ADDR_WIDTH = 10
)(
	input wire clk,
	input wire [DATA_WIDTH-1:0] data,
	input wire strobe,
	
	//Interface to packet mem
	output wire [ADDR_WIDTH-1:0] wr_addr,
	output wire [DATA_WIDTH-1:0] wr_data,
	input wire mem_ready,
	output wire wr_en,
	output wire done
);

assign wr_data = data; //TODO: make this work for arbitrary widths

reg [ADDR_WIDTH-1:0] addr = 0;
wire [ADDR_WIDTH-1:0] next_addr;

assign wr_en = (mem_ready && strobe);

//make done = 1 on our last write
assign done = (addr == FLITS_PER_PACKET - 1) && wr_en;

assign next_addr = wr_en ? (done ? 0 : addr + 1) : addr;

always @(posedge clk) begin
	addr <= next_addr;
end

assign wr_addr = addr;

endmodule
