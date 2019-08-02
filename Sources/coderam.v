`timescale 1ns / 1ps

/*

coderam.v

A simple Verilog file that implements SDP (simple dual port) RAM. The reason for
choosing SDP is because the FPGA's BRAMs already support it "at no extra cost".
If instead I tried multiplexing the address port, I would add propagation delays
and a bunch of extra logic.

Okay, I've confirmed this uses BRAMs.

*/


module coderam # (parameter
    ADDR_WIDTH = 10,
    DATA_WIDTH = 64, //TODO: I might try shrinking the opcodes at some point
    localparam DEPTH = 2**ADDR_WIDTH
)(
    input wire clk,
    input wire ce, //Clock enable
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output reg [DATA_WIDTH-1:0] rd_data
);

reg [DATA_WIDTH-1:0] data[0:DEPTH-1];

always @(posedge clk) begin
    if (ce) begin
        if (wr_en) begin
            data[wr_addr] <= wr_data;
        end
        rd_data = data[rd_addr];
    end
end


endmodule
