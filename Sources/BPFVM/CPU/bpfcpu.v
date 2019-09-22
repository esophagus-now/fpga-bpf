`timescale 1ns / 1ps
/*
bpfcpu.v

Basically just connects bpfvm_ctrl.v and bpfvm_datapath.v together into one block
(known as the BPF CPU core)

*/


module bpfcpu # (
    parameter CODE_ADDR_WIDTH = 10, // codemem depth = 2^CODE_ADDR_WIDTH
    parameter PACKET_BYTE_ADDR_WIDTH = 12, // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    parameter SNOOP_FWD_ADDR_WIDTH = 9
)(
	input wire rst,
	input wire clk,
	input wire mem_ready, //Signal from packetmem.v
	input wire [SNOOP_FWD_ADDR_WIDTH-1:0] packet_len, //TODO: fix this terrible packet length logic
	output wire packet_mem_rd_en,
	output wire inst_mem_rd_en,
	input wire [63:0] inst_mem_data, //Instructions always 64 bits wide
	input wire [31:0] packet_data, //Hardcoded to 32 bits. Final decision.
	output wire [PACKET_BYTE_ADDR_WIDTH-1:0] packet_addr,
	output wire [CODE_ADDR_WIDTH-1:0] inst_rd_addr,
	output wire [1:0] transfer_sz,
	output wire cpu_acc,
	output wire cpu_rej
);

//There's no way I'll remember what all of these are in a few weeks.

wire [2:0] A_sel; //Select lines for next value of A register
wire [2:0] X_sel; //Select lines for next value of X register
wire [1:0] PC_sel; //Select lines for next value of PC register
wire addr_sel; //Select lines for packet read address (either absolute or indirect address)
wire A_en; //Enable line for register A
wire X_en; //Enable line for register X
wire PC_en; //Enable line for register PC
wire PC_rst; //Currently not used
wire B_sel; //Selects second ALU operand (X or immediate)
wire [3:0] ALU_sel; //Selects ALU operation
//There is an instruction in BPF which loads A or X with the packet's length,
//so we'll have to calculate that somehow
wire regfile_wr_en; //Write enable for the register file
wire regfile_sel; //Selects the desired register within the file ("address lines")
wire [15:0] opcode; //Named subfield of the instruction (for the opcode, in case it wasn't clear)
wire set; //Output from ALU: A & B != 0
wire eq; //Output from ALU: A == B
wire gt; //Output from ALU: A > B
wire ge; //Output from ALU: A >= B
wire imm_is_zero; //Output from "ALU": imm == 0 
wire A_is_zero; //Output from "ALU": A == 0 
wire X_is_zero; //Output from "ALU": X == 0 

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
	.regfile_wr_en(regfile_wr_en),
	.regfile_sel(regfile_sel),
	.opcode(opcode),
	.set(set),
	.eq(eq),
	.gt(gt),
	.ge(ge),
	.packet_mem_rd_en(packet_mem_rd_en),
	.inst_mem_rd_en(inst_mem_rd_en),
	.transfer_sz(transfer_sz),
	.mem_ready(mem_ready),
	.A_is_zero(A_is_zero),
	.imm_is_zero(imm_is_zero),
	.X_is_zero(X_is_zero),
	.accept(cpu_acc),
	.reject(cpu_rej)
);

bpfvm_datapath # (
	.CODE_ADDR_WIDTH(CODE_ADDR_WIDTH),
	.PACKET_BYTE_ADDR_WIDTH(PACKET_BYTE_ADDR_WIDTH)
) datapath (
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
	.PC(inst_rd_addr),
	.imm_is_zero(imm_is_zero),
	.X_is_zero(X_is_zero),
	.A_is_zero(A_is_zero)
);

endmodule
