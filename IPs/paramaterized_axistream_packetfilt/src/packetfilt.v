`timescale 1ns / 1ps
/*
packetfilt.v

Intended to be a top-level module for a packaged IP. For now, it only grafts an AXI 
slave onto the interface for adding new instructions. In the future, it should also
include some way to add a parameterizable number of snoopers as well as manage their
configuration.
*/

//I didn't have great luck with localparams
`define PACKET_DATA_WIDTH (2**(3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH))
//God what a mess... need to fix the packet length soon!
`define PLEN_WIDTH (SNOOP_FWD_ADDR_WIDTH+1)

module packetfilt # (
    parameter CODE_ADDR_WIDTH = 10, // codemem depth = 2^CODE_ADDR_WIDTH
    parameter PACKET_BYTE_ADDR_WIDTH = 12, // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    parameter SNOOP_FWD_ADDR_WIDTH = 9
    //this makes the data width of the snooper and fwd equal to:
    // 2^{3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH}
)(

    // Clock and Reset
    input  wire                      axi_aclk,
    input  wire                      rst,
    
    //Interface to snooper
    input wire [SNOOP_FWD_ADDR_WIDTH-1:0] snooper_wr_addr,
	input wire [`PACKET_DATA_WIDTH-1:0] snooper_wr_data, //Hardcoded to 64 bits. TODO: change this to a parameter?
	input wire snooper_wr_en,
	input wire snooper_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_snooper,
    
	//Interface to forwarder
	input wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data,
	input wire forwarder_rd_en,
	input wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_forwarder,
	output wire [`PLEN_WIDTH-1:0] len_to_forwarder,
	
	//Interface to codemem
	input wire [CODE_ADDR_WIDTH-1:0] code_mem_wr_addr,
	input wire [63:0] code_mem_wr_data, //Instructions are always 64 bits wide
	input wire code_mem_wr_en
);

bpfvm # (
    .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH), // codemem depth = 2^CODE_ADDR_WIDTH
    .PACKET_BYTE_ADDR_WIDTH(PACKET_BYTE_ADDR_WIDTH), // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    .SNOOP_FWD_ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH)
) the_VM(
	.rst(rst), //Reset should be high if resetn is LOW or if start is LOW 
	.clk(axi_aclk),
	//Interface to an external module which will fill codemem
	.code_mem_wr_addr(code_mem_wr_addr),
	.code_mem_wr_data(code_mem_wr_data),
	.code_mem_wr_en(code_mem_wr_en),
    
    //Interface to snooper
	.snooper_wr_addr(snooper_wr_addr),
	.snooper_wr_data(snooper_wr_data), //Hardcoded to 32 bits. TODO: change this to 64?
	.snooper_wr_en(snooper_wr_en),
	.snooper_done(snooper_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_snooper(ready_for_snooper),
    
	//Interface to forwarder
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder),
	.len_to_forwarder(len_to_forwarder)
);

endmodule


`undef PACKET_DATA_WIDTH
`undef PLEN_WIDTH