`timescale 1ns / 1ps
/*

packetmem.v

This file implements a special memory block with the following capabilites:
 - 32 bit write port (using this module's wr_addr, idata, and wr_en inputs)
 - 8-, 16-, or 32-bit reads from any byte address (using the rest of the inputs/outputs)
   - Outputs is always 32-bits; if you ask for a smaller size, it is left-padded with zeros
 - (TODO) Ping-ponging between the read and write ports
 
The intention here is for this module to fill up the "ping" buffer with a packet
while a BPF interpreter reads its "pong" buffer to decide whether to forward that
packet. Of course, the buffers are switched when needed.

This module instantiates two packetram modules as its ping and pong buffers.

*/

//Assumes packetram is 32 bits wide (per port)

module packetmem#(parameter
    ADDR_WIDTH = 10 
)(
	//TODO: add pipeline signalling
	
	//Interface to snooper
	input wire [ADDR_WIDTH-1:0] snooper_wr_addr,
	input wire [63:0] snooper_wr_data,
	input wire snooper_wr_en,
	
	//Interface to CPU
	input wire [ADDR_WIDTH+2-1:0] cpu_byte_rd_addr,
	input wire [1:0] transfer_sz,
	output wire [32:0] cpu_rd_data,
	input wire cpu_rd_en,
	
	//Interface to forwarder
	input wire [ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [63:0] forwarder_rd_data,
	input wire forwarder_rd_en
);

/* Kept here for reference
packetram # (
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(`DATA_WIDTH)
) ping (
    .clk(clk),
    .en(packetram_clock_en),
    .addra(addrA),
    .addrb(addrB),
    .doa(packetram_do[2*`DATA_WIDTH-1:`DATA_WIDTH]),
    .dob(packetram_do[`DATA_WIDTH-1:0]),
    .dia(idata),
    .wr_en(wr_en)
);
*/

endmodule
