`timescale 1ns / 1ps
/*
codemem.v

Instantiates coderam module and presents an interface with rd_en and wr_en (instead
of clock_en and wr_en).

*/


module codemem # (parameter
    ADDR_WIDTH = 10,
    DATA_WIDTH = 64, //TODO: I might try shrinking the opcodes at some point
    DEPTH = 2**ADDR_WIDTH
)(
    input wire clk,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [DATA_WIDTH-1:0] rd_data,
    input wire rd_en
);

wire clock_en;
assign clock_en = rd_en | wr_en;

coderam # (.ADDR_WIDTH(ADDR_WIDTH),.DATA_WIDTH(DATA_WIDTH)) myram (
    .clk(clk),
    .ce(clock_en),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .wr_en(wr_en),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
);

endmodule
