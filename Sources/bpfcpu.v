`timescale 1ns / 1ps
/*
bpfcpu.v

Basically just connects bpfvm_ctrl.v and bpfvm_datapath.v together into one block
(known as the BPF CPU core)

*/


module bpfcpu(
	input wire rst,
	input wire clk,
	output wire packet_mem_rd_en,
	output wire inst_mem_rd_en,
	input wire [63:0] inst_mem_data,
	input wire [63:0] packet_data,
	output wire [31:0] packet_addr,
	output wire [31:0] inst_rd_addr
);

wire [2:0] A_sel;
wire [2:0] X_sel;
wire [1:0] PC_sel;
wire addr_sel;
wire A_en;
wire X_en;
wire PC_en;
wire PC_rst;
wire B_sel;
wire [3:0] ALU_sel;
wire [63:0] packet_len;
wire regfile_wr_en;
wire regfile_sel;
wire [15:0] opcode;
wire set;
wire eq;
wire gt;
wire ge;
wire [1:0] transfer_sz; 

bpfvm_ctrl controller(	.rst(rst),
	.clk(clk),
	.A_sel(A_sel),
	.X_sel(X_sel),
	.PC_sel(PC_sel),
	.addr_sel(addr_sel),
	.A_en(A_en),
	.X_en(X_en),
	.PC_en(PC_en),
	.PC_rst(PC_rst),
	.B_sel(B_sel),
	.ALU_sel(ALU_sel),
	.packet_len(packet_len),
	.regfile_wr_en(regfile_wr_en),
	.regfile_sel(regfile_sel),
	.opcode(opcode),
	.set(set),
	.eq(eq),
	.gt(gt),
	.ge(ge),
	.packet_mem_rd_en(packet_mem_rd_en),
	.inst_mem_rd_en(inst_mem_rd_en),
	.transfer_sz(transfer_sz)
);

//Tada!!!

bpfvm_datapath datapath(
	.rst(rst),
	.clk(clk),
	.A_sel(A_sel),
	.X_sel(X_sel),
	.PC_sel(PC_sel),
	.addr_sel(addr_sel),
	.A_en(A_en),
	.X_en(X_en),
	.PC_en(PC_en),
	.PC_rst(PC_rst),
	.B_sel(B_sel),
	.ALU_sel(ALU_sel),
	.inst_mem_data(inst_mem_data),
	.packet_data(packet_data),
	.packet_len(packet_len),
	.regfile_wr_en(regfile_wr_en),
	.regfile_sel(regfile_sel),
	.opcode(opcode),
	.set(set),
	.eq(eq),
	.gt(gt),
	.ge(ge),
	.packet_addr(packet_addr),
	.PC(inst_rd_addr)
);

endmodule
