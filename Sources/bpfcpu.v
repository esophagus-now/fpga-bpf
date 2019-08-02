`timescale 1ns / 1ps
/*
bpfcpu.v

Basically just connects bpfvm_ctrl.v and bpfvm_datapath.v together into one block
(known as the BPF CPU core)

*/


module bpfcpu # (parameter
	CODE_ADDR_WIDTH = 10,
	CODE_DATA_WIDTH = 64,
	PACKET_BYTE_ADDR_WIDTH = 12,
	PACKET_ADDR_WIDTH = (PACKET_BYTE_ADDR_WIDTH - 2),
	PACKET_DATA_WIDTH = 32
)(
	//TODO: pipeline signals
	//TODO: fix this damned mess of parameters and constants!
	input wire rst,
	input wire clk,
	output wire packet_mem_rd_en,
	output wire inst_mem_rd_en,
	input wire [CODE_DATA_WIDTH-1:0] inst_mem_data,
	input wire [PACKET_DATA_WIDTH-1:0] packet_data,
	output wire [PACKET_ADDR_WIDTH-1:0] packet_addr,
	output wire [CODE_ADDR_WIDTH-1:0] inst_rd_addr,
	output wire [1:0] transfer_sz 
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
wire [63:0] packet_len; //Should this be an external signal?
wire regfile_wr_en;
wire regfile_sel;
wire [15:0] opcode;
wire set;
wire eq;
wire gt;
wire ge;

bpfvm_ctrl controller(	
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
