`timescale 1ns / 1ps
/*
fwdcombine.v

Unlike snoopsplit, which just looks for the next available VM, fwdcombine is more like
a MUX. This is specifically designed for guaranteed in-order forwarding, the details of
which will be described on the project wiki.
*/


//God what a mess... need to fix the packet length soon!
`define PLEN_WIDTH (ADDR_WIDTH+1)

module fwdcombine # (parameter
	DATA_WIDTH = 64,
	ADDR_WIDTH = 9
)(
	input wire clk,
	input wire sel,	
	
	//Interface to packetmem, as the output of the VM (or the last split stage)
	output wire [ADDR_WIDTH-1:0] forwarder_rd_addr_left,
	input wire [DATA_WIDTH-1:0] forwarder_rd_data_left,
	output wire forwarder_rd_en_left,
	output wire forwarder_done_left, //NOTE: this must be a 1-cycle pulse.
	input wire ready_for_forwarder_left,
	input wire [`PLEN_WIDTH-1:0] len_to_forwarder_left,
	
	output wire [ADDR_WIDTH-1:0] forwarder_rd_addr_right,
	input wire [DATA_WIDTH-1:0] forwarder_rd_data_right,
	output wire forwarder_rd_en_right,
	output wire forwarder_done_right, //NOTE: this must be a 1-cycle pulse.
	input wire ready_for_forwarder_right,
	input wire [`PLEN_WIDTH-1:0] len_to_forwarder_right,
	
	//Interface to packetmem, as the input of the forwarder (or the next split stage)
	input wire [ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [DATA_WIDTH-1:0] forwarder_rd_data,
	input wire forwarder_rd_en,
	input wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_forwarder,
	output wire [`PLEN_WIDTH-1:0] len_to_forwarder
);
	
//"Right to left" signals 
assign forwarder_rd_addr_left = forwarder_rd_addr;
assign forwarder_rd_addr_right = forwarder_rd_addr;
assign forwarder_rd_en_left = (sel == 0) ? forwarder_rd_en : 0;
assign forwarder_rd_en_right = (sel == 1) ? forwarder_rd_en : 0;
assign forwarder_done_left = (sel == 0) ? forwarder_done : 0;
assign forwarder_done_right = (sel == 1) ? forwarder_done : 0;


//"Left to right" signals 
assign forwarder_rd_data = (sel == 0) ? forwarder_rd_data_left : forwarder_rd_data_right;
assign ready_for_forwarder = (sel == 0) ? ready_for_forwarder_left : ready_for_forwarder_right;
assign len_to_forwarder = (sel == 0) ? len_to_forwarder_left : len_to_forwarder_right;
	
endmodule

`undef PLEN_WIDTH
