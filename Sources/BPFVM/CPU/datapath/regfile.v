`timescale 1ns / 1ps
/*

regfile.v

The BPF VM defines "scratch memory" where you can load and store values (in addition
to being able to load data from the packet itself). This is basically a fancy way of
saying a "register file", so that's what this module implements.

Note that I (intentionally) use ASYNchronous reads and SYNchronous writes. First,
this is the behaviour I wanted, and also, I have confirmed that Vivado synthesizes this
as LUT RAM.

This module is instantiated as part of bpfvm_datapath.

*/

module regfile(
    input wire clk,
    input wire [3:0] addr,
    input wire [31:0] idata,
    input wire wr_en,
    output wire [31:0] odata
);

//Scratch memory (a.k.a. register file)
reg [31:0] scratch [0:15];

//odata's value is found by selecting one of the storage registers usign a MUX
assign odata = scratch[addr];

//At clock edge, write new contents at right(write) location
always @(posedge clk) begin
    if (wr_en == 1'b1) begin
        scratch[addr] <= idata;
    end
end

endmodule
