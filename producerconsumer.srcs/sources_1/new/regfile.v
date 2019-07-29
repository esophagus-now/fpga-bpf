`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2019 11:13:33 AM
// Design Name: 
// Module Name: regfile
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


/*
reg [31:0] scratch [0:15];
wire [3:0] scratch_addr;
assign scratch_addr = imm[3:0];
wire [31:0] scratch_odata;
wire [31:0] scratch_idata;
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
