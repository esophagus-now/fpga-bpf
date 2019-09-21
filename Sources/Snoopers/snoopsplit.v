`timescale 1ns / 1ps
/*
snoopsplit.v

Intended to be an easier way to have a configurable number of parallel CPUs in a packet filter.

You would have one snooper, one forwarded, and multiple CPUs if a single CPU is too slow to
keep up. Due to the nature of packet filtering, it's relatively to run multiple CPUs in 
parallel.

This is meant to be one "splitter" in a "corporate feed structure" of other splitters. 

Note that mem_ready and wr_en are very much like ready and valid on AXI Stream. For this
reason I've chose to keep these as combinational paths, at risk of having problems with
long paths later
*/


module snoopsplit # (parameter
	DATA_WIDTH = 64,
	ADDR_WIDTH = 10
)(
	input wire clk,
	//Interface to packet mem, as the output of the snooper (or previous split stage)
	input wire [ADDR_WIDTH-1:0] wr_addr,
	input wire [DATA_WIDTH-1:0] wr_data,
	output wire mem_ready,
	input wire wr_en,
	input wire done,
	
	//Interface to packet mem, as the input of the VM (or next split stage)
	output wire [ADDR_WIDTH-1:0] wr_addr_left,
	output wire [DATA_WIDTH-1:0] wr_data_left,
	input wire mem_ready_left,
	output wire wr_en_left,
	output wire done_left,
	output wire [ADDR_WIDTH-1:0] wr_addr_right,
	output wire [DATA_WIDTH-1:0] wr_data_right,
	input wire mem_ready_right,
	output wire wr_en_right,
	output wire done_right,
	
	//Output which branch we chose, which is later used to put packets back into
	//the right order
	output reg choice
    );

initial choice <= 0; //Zero for left, 1 for right

wire nextchoice;
assign nextchoice = (mem_ready_left ? 0 : (mem_ready_right ? 1 : 0));

assign wr_addr_left = wr_addr;
assign wr_addr_right = wr_addr;
assign wr_data_left = wr_data;
assign wr_data_right = wr_data;

assign mem_ready = (mem_ready_left || mem_ready_right);

assign wr_en_left = (choice == 0) ? wr_en : 0;
assign wr_en_right = (choice == 1) ? wr_en : 0;
assign done_left = (choice == 0) ? done : 0;
assign done_right = (choice == 1) ? done : 0;

always @(posedge clk) begin
	if (done) choice <= nextchoice;
end

endmodule
