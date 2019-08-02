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

By the way, packetramtb.sv has a simple testbench for this file.


* https://www.xilinx.com/support/documentation/sw_manuals/xilinx11/xst.pdf 

*/


module packetram # (parameter 
    ADDR_WIDTH = 10,
    DATA_WIDTH = 32
)(
    input clk,
    input en, //clock enable

    input [ADDR_WIDTH-1:0] addra,
    input [ADDR_WIDTH-1:0] addrb,
    output reg [DATA_WIDTH-1:0] doa,
    output reg [DATA_WIDTH-1:0] dob,
    
    input [DATA_WIDTH-1:0] dia,
    input wr_en

);

localparam DEPTH = 2**ADDR_WIDTH;

reg [DATA_WIDTH-1:0] data [0:DEPTH-1];

always @(posedge clk) begin
    if (en) begin
        if (wr_en == 1'b1) begin
            data[addra] <= dia;
        end
        doa <= data[addra]; //Read-first mode
        dob <= data[addrb];
    end
end
endmodule
