`timescale 1ns / 1ps
/*

packetram.v

This module (written by referencing the Xilinx XST user guide (UG627)* is
simply a synchronous RAM module which uses dual-port reads to read two
32 bit words at once (note: it only uses one of he write ports, and only
writes 32 bits at once). I have confirmed that it synthesizes into a BRAM.

This module is instantiated by the packetmem module.

Why do we need to read two words at once? This is in order to support single-
cycle unaligned memory reads. It is possible that a single read will span two
words in memory, so we use this dual-port trick to read both words at once.

By the way, packetramtb.sv has a(N OUT OF DATE) simple testbench for this file.


* https://www.xilinx.com/support/documentation/sw_manuals/xilinx11/xst.pdf 

*/


module packetram_wrapped # (parameter 
    PORT_ADDR_WIDTH = 10,
    PORT_DATA_WIDTH = 32
)(
    input clk,
    input en, //clock enable

    input [PORT_ADDR_WIDTH-1:0] addra,
    input [PORT_ADDR_WIDTH-1:0] addrb,
    output reg [PORT_DATA_WIDTH-1:0] doa,
    output reg [PORT_DATA_WIDTH-1:0] dob,
    
    input [PORT_ADDR_WIDTH-1:0] dia,
    input [PORT_ADDR_WIDTH-1:0] dib,
    input wr_en

);

localparam DEPTH = 2**PORT_ADDR_WIDTH;

reg [PORT_DATA_WIDTH-1:0] data [0:DEPTH-1];

always @(posedge clk) begin
    if (en) begin
        if (wr_en == 1'b1) begin
            data[addra] <= dia;
        end
        doa <= data[addra]; //Read-first mode
    end
end

always @(posedge clk) begin
    if (en) begin
        if (wr_en == 1'b1) begin
            data[addrb] <= dib;
        end
        dob <= data[addrb]; //Read-first mode
    end
end
endmodule

//Chenge to use rd_en instead of clock enable
module packet_ram # (
	parameter PORT_ADDR_WIDTH = 10,
    parameter PORT_DATA_WIDTH = 32
)(
    input clk,
    input [PORT_ADDR_WIDTH-1:0] addra,
    input [2*PORT_DATA_WIDTH-1:0] di,
    input wr_en,
    input rd_en, //read enable
    output [2*PORT_DATA_WIDTH-1:0] do,
    
    //Signals for managing length
    //TODO: This logic is spread all over the place. Fix that.
    input wire len_rst,
    output reg [PORT_ADDR_WIDTH-1:0] len = 0
);

wire [PORT_ADDR_WIDTH-1:0] addrb;
assign addrb = addra + 1;

always @(posedge clk) begin
	if (len_rst) len <= 0;
	else if (addra > len && wr_en) len <= addra;
end

packetram_wrapped # ( 
    .PORT_ADDR_WIDTH(PORT_ADDR_WIDTH),
    .PORT_DATA_WIDTH(PORT_DATA_WIDTH)
) meminst (
	.clk(clk),
	.en(wr_en | rd_en), //clock enable

	.addra(addra),
	.addrb(addrb),
	.doa(do[2*PORT_DATA_WIDTH-1:PORT_DATA_WIDTH]),
	.dob(do[PORT_DATA_WIDTH-1:0]),
    
	.dia(di[2*PORT_DATA_WIDTH-1:PORT_DATA_WIDTH]),
	.dib(di[PORT_DATA_WIDTH-1:0]),
	.wr_en(wr_en)
);

endmodule