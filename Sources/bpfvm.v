`timescale 1ns / 1ps
/*
bpfvm.v

Wires up the BPF CPU core (bpfcpu.v) with instruction and packet memory.

*/

//TODO: Fix this
`define CODE_ADDR_WIDTH 10
`define CODE_DATA_WIDTH 64 
`define PACKET_BYTE_ADDR_WIDTH 12
`define PACKET_ADDR_WIDTH (`PACKET_BYTE_ADDR_WIDTH - 2)
`define PACKET_DATA_WIDTH 32

module bpfvm(
	//TODO: add proper signalling for backpressure and valid
	input wire rst,
	input wire clk,
    input wire [`CODE_ADDR_WIDTH-1:0] code_mem_wr_addr,
    input wire [`CODE_DATA_WIDTH-1:0] code_mem_wr_data,
    input wire code_mem_wr_en,
    input wire [`PACKET_ADDR_WIDTH-1:0] packet_mem_wr_addr,
    input wire [`PACKET_DATA_WIDTH-1:0] packet_mem_wr_data,
    input wire packet_mem_wr_en
);

wire [31:0] inst_rd_addr;
wire [63:0] inst_mem_data;
wire inst_mem_rd_en;

wire [63:0] packet_mem_rd_data;
wire [`PACKET_BYTE_ADDR_WIDTH-1:0] packet_mem_rd_addr;
wire packet_mem_rd_en;

wire [1:0] sz;
	
bpfcpu # (
	.CODE_ADDR_WIDTH(`CODE_ADDR_WIDTH),
	.CODE_DATA_WIDTH(`CODE_DATA_WIDTH),
	.PACKET_BYTE_ADDR_WIDTH(`PACKET_BYTE_ADDR_WIDTH),
	.PACKET_ADDR_WIDTH(`PACKET_ADDR_WIDTH),
	.PACKET_DATA_WIDTH(`PACKET_DATA_WIDTH)
) theCPU (
	.rst(rst),
	.clk(clk),
	.packet_mem_rd_en(packet_mem_rd_en),
	.inst_mem_rd_en(inst_mem_rd_en),
	.inst_mem_data(inst_mem_data),
	.packet_data(packet_mem_rd_data),
	.packet_addr(packet_mem_rd_addr),
	.inst_rd_addr(inst_rd_addr),
	.transfer_sz(sz)
);

codemem # (
    .ADDR_WIDTH(`CODE_ADDR_WIDTH),
    .DATA_WIDTH(`CODE_DATA_WIDTH)
) instruction_memory (
	.clk(clk),
	.wr_addr(code_mem_wr_addr),
	.wr_data(code_mem_wr_data),
	.wr_en(code_mem_wr_en),
	.rd_addr(inst_rd_addr),
	.rd_data(inst_mem_data),
	.rd_en(inst_mem_rd_en)
);

packetmem packet_memory(
	.clk(clk),
	.rd_addr(packet_mem_rd_addr),
	.sz(sz), 
	.rd_en(packet_mem_rd_en), 
	.odata(packet_mem_rd_data),
	.wr_addr(packet_mem_wr_addr),
	.idata(packet_mem_wr_data),
	.wr_en(packet_mem_wr_en)
);

endmodule
