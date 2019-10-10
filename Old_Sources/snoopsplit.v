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
	ADDR_WIDTH = 10,
	PESSIMISTIC = 0
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
reg done_on_prev_cycle = 1;
always @(posedge clk) done_on_prev_cycle <= done;

reg choice_internal_saved = 0; //Hold onto last choice in case we're not allowed to change choice
//(that is, when do_select is false)

wire do_select;
assign do_select = 
	done_on_prev_cycle || 
	(choice_internal_saved == 0 && !mem_ready_left) || 
	(choice_internal_saved == 1 && !mem_ready_right);

wire choice_internal;
assign choice_internal = 
	(do_select) ? 
		(mem_ready_left ? 0 : (mem_ready_right ? 1 : 0))
		:
		choice_internal_saved
	;

wire choice_valid;
assign choice_valid = mem_ready;

always @(posedge clk) choice_internal_saved <= choice_internal;

assign mem_ready = (mem_ready_left || mem_ready_right);

wire [ADDR_WIDTH-1:0] wr_addr_internal;
wire [DATA_WIDTH-1:0] wr_data_internal;
wire wr_en_left_internal;
wire done_left_internal;
wire wr_en_right_internal;
wire done_right_internal;

////////////////////////////////////////
////////// PESSIMISTIC MODE ////////////
////////////////////////////////////////
generate
if (PESSIMISTIC) begin
	//Delay all outputs to packet mem by one cycle
	reg [ADDR_WIDTH-1:0] wr_addr_r = 0;
	reg [DATA_WIDTH-1:0] wr_data_r = 0;
	reg wr_en_left_r = 0;
	reg done_left_r = 0;
	reg wr_en_right_r = 0;
	reg done_right_r = 0;
	
	reg choice_r = 0;
	
	//Delay all outputs by one cycle
	always @(posedge clk) begin
		wr_addr_r = wr_addr;
		wr_data_r = wr_data;
	
		wr_en_left_r = (choice_internal == 0 && choice_valid) ? wr_en : 0;
		wr_en_right_r = (choice_internal == 1 && choice_valid) ? wr_en : 0;
		done_left_r = (choice_internal == 0 && choice_valid) ? done : 0;
		done_right_r = (choice_internal == 1 && choice_valid) ? done : 0;
		
		choice_r <= choice_internal;
	end
	
	assign wr_addr_internal = wr_addr_r;
	assign wr_data_internal = wr_data_r;
	
	assign wr_en_left_internal = wr_en_left_r;
	assign wr_en_right_internal = wr_en_right_r;
	assign done_left_internal = done_left_r;
	assign done_right_internal = done_right_r;
	
	assign choice = choice_r;
end
///////////////////////////////////////
////////// OPTIMISTIC MODE ////////////
///////////////////////////////////////
else begin
	assign wr_addr_internal = wr_addr;
	assign wr_data_internal = wr_data;
	
	assign wr_en_left_internal = (choice_internal == 0 && choice_valid) ? wr_en : 0;
	assign wr_en_right_internal = (choice_internal == 1 && choice_valid) ? wr_en : 0;
	assign done_left_internal = (choice_internal == 0 && choice_valid) ? done : 0;
	assign done_right_internal = (choice_internal == 1 && choice_valid) ? done : 0;
	
	assign choice = choice_internal;
end
endgenerate
///////////////////////////////////////

assign wr_addr_left = wr_addr_internal;
assign wr_data_left = wr_data_internal;
assign wr_en_left = wr_en_left_internal;
assign done_left = done_left_internal;

assign wr_addr_right = wr_addr_internal;
assign wr_data_right = wr_data_internal;
assign wr_en_right = wr_en_right_internal;
assign done_right = done_right_internal;
endmodule
