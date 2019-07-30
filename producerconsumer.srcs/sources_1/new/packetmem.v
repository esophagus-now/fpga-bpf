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

//TODO: fix offsetting into 64 bit word for 8- and 16-bit reads
//TODO: fix logic so that it uses the proper encodings for the transfer size

*/


//Assumes big-endianness

`define DATA_WIDTH 32

module packetmem#(parameter
    BYTE_ADDR_WIDTH = 12,
    localparam ADDR_WIDTH = BYTE_ADDR_WIDTH - 2 //This assumes that the memory is 32 bits wide
)(
    input wire clk,
    //How many bits for the address width? Should that be a parameter?
    input wire [BYTE_ADDR_WIDTH-1:0] rd_addr,
    input wire [1:0] sz, //00 for byte (8b), 01 for half-word (16b), or 10 for word (32b)
    input wire rd_en, 
    output wire [`DATA_WIDTH-1:0] odata, //Always padded to 32 bits (left padded with zeros)
    //sign extension?
    
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [`DATA_WIDTH-1:0] idata,
    input wire wr_en
);


//Round byte address down to (aligned) 32-bit word address 
wire [9:0] addrA;
assign addrA = (wr_en == 1'b1) ? wr_addr : rd_addr[BYTE_ADDR_WIDTH-1:2];
wire [9:0] addrB;
assign addrB = rd_addr[BYTE_ADDR_WIDTH-1:2] + 1; //Port B is only used when performing 64 bit reads, so it's ok to
//use rd_addr here. Anyway, it has less propagation delay, so I think it's better
//(Note to self: this used to set addrB to be addrA+1)

//This is the offset of the 32 bit word inside the 64-bit word pointed at by addrA and addrB
wire [1:0] offset;
assign offset = rd_addr[1:0];

wire packetram_clock_en; 
assign packetram_clock_en = rd_en | wr_en;

wire [2*`DATA_WIDTH-1:0] packetram_do;

//TODO: figure out how I'll do ping-ponging
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

//This is written assuming DATA_WIDTH is 32
//We need to deal with the offset into the 64 bit word
wire [`DATA_WIDTH-1:0] offset0, offset1, offset2, offset3;
assign offset0 = packetram_do[2*`DATA_WIDTH-1:2*`DATA_WIDTH-32];
assign offset1 = packetram_do[2*`DATA_WIDTH-1-8:2*`DATA_WIDTH-32-8];
assign offset2 = packetram_do[2*`DATA_WIDTH-1-16:2*`DATA_WIDTH-32-16];
assign offset3 = packetram_do[2*`DATA_WIDTH-1-24:2*`DATA_WIDTH-32-24];
//This "selected" vector is the desired part ofthe 4-bit word, based on the offset
wire [`DATA_WIDTH-1:0] selected;
assign selected = (offset[1] == 1'b1) ? (
                    (offset[0] == 1'b1) ? offset3 : offset2
                  ):( 
                    (offset[0] == 1'b1) ? offset1 : offset0
                  );

//This assumes the encoding for sz is as follows:
//00 for byte (8b), 01 for half-word (16b), or 10 for word (32b)
//The remaining parts of odata are zero-padded
assign odata[7:0] = selected[7:0]; 
assign odata[15:8] = (sz[0] | sz[1]) ? selected[15:8] : 0;
assign odata[31:16] = (sz[1]) ? selected[31:16] : 0;


endmodule
