`timescale 1ns / 1ps
/*
fwdcombine_tb.sv

A simple testbench for the combiner. Tests three combiners arranged in a tree:
A__
   \_comb1_
B__/       \(left)
            \
             \_comb0__
             /
C__         /(right)
   \_comb2_/
D)_/
*/

`define DATA_WIDTH 64
`define ADDR_WIDTH 10
//God what a mess... need to fix the packet length soon!
`define PLEN_WIDTH (`ADDR_WIDTH+1)

`define SHORT_DELAY repeat(5) @(posedge clk)
`define LONG_DELAY repeat(10) @(posedge clk)
`define SYNC @(posedge clk)

module fwdcombine_tb();
reg clk;

//BPFVM A
wire [`ADDR_WIDTH-1:0] forwarder_rd_addr_A;
reg [`DATA_WIDTH-1:0] forwarder_rd_data_A;
wire forwarder_rd_en_A;
wire forwarder_done_A; //NOTE: this must be a 1-cycle pulse.
reg ready_for_forwarder_A;
reg [`PLEN_WIDTH-1:0] len_to_forwarder_A;

//BPFVM B
wire [`ADDR_WIDTH-1:0] forwarder_rd_addr_B;
reg [`DATA_WIDTH-1:0] forwarder_rd_data_B;
wire forwarder_rd_en_B;
wire forwarder_done_B; //NOTE: this must be a 1-cycle pulse.
reg ready_for_forwarder_B;
reg [`PLEN_WIDTH-1:0] len_to_forwarder_B;

//BPFVM C
wire [`ADDR_WIDTH-1:0] forwarder_rd_addr_C;
reg [`DATA_WIDTH-1:0] forwarder_rd_data_C;
wire forwarder_rd_en_C;
wire forwarder_done_C; //NOTE: this must be a 1-cycle pulse.
reg ready_for_forwarder_C;
reg [`PLEN_WIDTH-1:0] len_to_forwarder_C;

//BPFVM D
wire [`ADDR_WIDTH-1:0] forwarder_rd_addr_D;
reg [`DATA_WIDTH-1:0] forwarder_rd_data_D;
wire forwarder_rd_en_D;
wire forwarder_done_D; //NOTE: this must be a 1-cycle pulse.
reg ready_for_forwarder_D;
reg [`PLEN_WIDTH-1:0] len_to_forwarder_D;

//"Output" of comb1. To be used as input to comb0 on the left
reg [`ADDR_WIDTH-1:0] forwarder_rd_addr_comb1;
wire [`DATA_WIDTH-1:0] forwarder_rd_data_comb1;
reg forwarder_rd_en_comb1;
reg forwarder_done_comb1; //NOTE: this must be a 1-cycle pulse.
wire ready_for_forwarder_comb1;
wire [`PLEN_WIDTH-1:0] len_to_forwarder_comb1;

//"Output" of comb2. To be used as input to comb0 on the right
reg [`ADDR_WIDTH-1:0] forwarder_rd_addr_comb2;
wire [`DATA_WIDTH-1:0] forwarder_rd_data_comb2;
reg forwarder_rd_en_comb2;
reg forwarder_done_comb2; //NOTE: this must be a 1-cycle pulse.
wire ready_for_forwarder_comb2;
wire [`PLEN_WIDTH-1:0] len_to_forwarder_comb2;

//"Output" of comb0
reg [`ADDR_WIDTH-1:0] forwarder_rd_addr;
wire [`DATA_WIDTH-1:0] forwarder_rd_data;
reg forwarder_rd_en;
reg forwarder_done; //NOTE: this must be a 1-cycle pulse.
wire ready_for_forwarder;
wire [`PLEN_WIDTH-1:0] len_to_forwarder;

fwdcombine # (
	.DATA_WIDTH(`DATA_WIDTH),
	.ADDR_WIDTH(`ADDR_WIDTH)
) comb1 (
	.clk(clk),

	.forwarder_rd_addr_left(forwarder_rd_addr_A),
	.forwarder_rd_data_left(forwarder_rd_data_A),
	.forwarder_rd_en_left(forwarder_rd_en_A),
	.forwarder_done_left(forwarder_done_A), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder_left(ready_for_forwarder_A),
	.len_to_forwarder_left(len_to_forwarder_A),
	.forwarder_rd_addr_right(forwarder_rd_addr_B),
	.forwarder_rd_data_right(forwarder_rd_data_B),
	.forwarder_rd_en_right(forwarder_rd_en_B),
	.forwarder_done_right(forwarder_done_B), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder_right(ready_for_forwarder_B),
	.len_to_forwarder_right(len_to_forwarder_B),
	
	.forwarder_rd_addr(forwarder_rd_addr_comb1),
	.forwarder_rd_data(forwarder_rd_data_comb1),
	.forwarder_rd_en(forwarder_rd_en_comb1),
	.forwarder_done(forwarder_done_comb1), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder_comb1),
	.len_to_forwarder(len_to_forwarder_comb1)
);

fwdcombine # (
	.DATA_WIDTH(`DATA_WIDTH),
	.ADDR_WIDTH(`ADDR_WIDTH)
) comb2 (
	.clk(clk),

	.forwarder_rd_addr_left(forwarder_rd_addr_C),
	.forwarder_rd_data_left(forwarder_rd_data_C),
	.forwarder_rd_en_left(forwarder_rd_en_C),
	.forwarder_done_left(forwarder_done_C), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder_left(ready_for_forwarder_C),
	.len_to_forwarder_left(len_to_forwarder_C),
	.forwarder_rd_addr_right(forwarder_rd_addr_D),
	.forwarder_rd_data_right(forwarder_rd_data_D),
	.forwarder_rd_en_right(forwarder_rd_en_D),
	.forwarder_done_right(forwarder_done_D), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder_right(ready_for_forwarder_D),
	.len_to_forwarder_right(len_to_forwarder_D),
	
	.forwarder_rd_addr(forwarder_rd_addr_comb2),
	.forwarder_rd_data(forwarder_rd_data_comb2),
	.forwarder_rd_en(forwarder_rd_en_comb2),
	.forwarder_done(forwarder_done_comb2), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder_comb2),
	.len_to_forwarder(len_to_forwarder_comb2)
);

fwdcombine # (
	.DATA_WIDTH(`DATA_WIDTH),
	.ADDR_WIDTH(`ADDR_WIDTH)
) comb0 (
	.clk(clk),

	.forwarder_rd_addr_left(forwarder_rd_addr_comb1),
	.forwarder_rd_data_left(forwarder_rd_data_comb1),
	.forwarder_rd_en_left(forwarder_rd_en_comb1),
	.forwarder_done_left(forwarder_done_comb1), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder_left(ready_for_forwarder_comb1),
	.len_to_forwarder_left(len_to_forwarder_comb1),
	.forwarder_rd_addr_right(forwarder_rd_addr_comb2),
	.forwarder_rd_data_right(forwarder_rd_data_comb2),
	.forwarder_rd_en_right(forwarder_rd_en_comb2),
	.forwarder_done_right(forwarder_done_comb2), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder_right(ready_for_forwarder_comb2),
	.len_to_forwarder_right(len_to_forwarder_comb2),
	
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder),
	.len_to_forwarder(len_to_forwarder)
);
endmodule
