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
	output wire choice //Zero for left, 1 for right
);

//Subtlety: we can only change our choice between packets. 
//This occurs _one cycle after_ done is asserted, or if nothing was ready on the last cycle
//ASSUMES: mem_ready never goes low intermittently inside of a single packet
reg do_select = 0;
always @(posedge clk) do_select <= done || (!mem_ready_left && !mem_ready_right);

reg choice_saved = 0; //Hold onto last choice in case we're not allowed to change choice
//(that is, when do_select is false)

assign choice = 
	do_select ? 
		(mem_ready_left ? 0 : (mem_ready_right ? 1 : 0))
		:
		choice_saved
	;

always @(posedge clk) choice_saved = choice;

assign wr_addr_left = wr_addr;
assign wr_addr_right = wr_addr;
assign wr_data_left = wr_data;
assign wr_data_right = wr_data;

assign mem_ready = (mem_ready_left || mem_ready_right);

assign wr_en_left = (choice == 0) ? wr_en : 0;
assign wr_en_right = (choice == 1) ? wr_en : 0;
assign done_left = (choice == 0) ? done : 0;
assign done_right = (choice == 1) ? done : 0;

endmodule
