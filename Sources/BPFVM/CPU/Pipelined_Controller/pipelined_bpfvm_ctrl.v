`timescale 1ns / 1ps
/*

pipelined_bpfvm_ctrl.v

This wires together all the separate stages of the pipelined controller.
This is actually the third complete rewrite of the BPF CPU controller!

I'm hoping that by pipeline, not only do we get improved performance, but
that timing is also eased.

*/

module pipelined_bpfvm_ctrl # (
	parameter PESSIMISTIC = 0
)(
    input wire rst,
    input wire clk,
    output wire [2:0] A_sel,
    output wire [2:0] X_sel,
    output wire [1:0] PC_sel,
    output wire addr_sel,
    output wire A_en,
    output wire X_en,
    output wire PC_en,
    output wire PC_rst,
    output wire B_sel,
    output wire [3:0] ALU_sel,
    output wire regfile_wr_en,
    output wire regfile_sel,
    input wire [15:0] opcode,
    input wire set,
    input wire eq,
    input wire gt,
    input wire ge,
    output wire packet_mem_rd_en,
    output wire inst_mem_rd_en,
    output wire [1:0] transfer_sz, //TODO: should this be in the datapath instead?
    input wire mem_ready, //Signal from packetmem.v; tells CPU when to start
    input wire A_is_zero,
    input wire X_is_zero,
    input wire imm_lsb_is_zero,
    output reg accept,
    output reg reject
);

//Internal wires
//Stage 0 outputs
wire [1:0] PC_sel_stage0;
wire PC_en_stage0;

//Stage 1 outputs
wire [3:0] ALU_sel_stage1;
wire [2:0] jmp_type; //PC_sel can only be determined in stage 2 when ALU flags are ready
wire PC_en_stage1; 
wire packet_mem_rd_en_stage1; 
wire [1:0] transfer_sz_stage1;
wire regfile_sel_stage1; 
wire regfile_wr_en_stage1;
wire [2:0] A_sel_stage1; 
wire A_en_stage1; 
wire [2:0] X_sel_stage1;
wire X_en_stage1;
wire stage1_stalled;

//Stage 2 outputs
wire PC_en_stage2;
wire [1:0] A_sel_stage2;
wire A_en_stage2;
wire [2:0] X_sel_stage2;
wire X_en_stage2;

//Stage 3 outputs
wire A_en_stage3;
wire X_en_stage3;

fetch_stage0 stage0(
		.clk(clk),
		.rst(rst),
		
		//Stall logic inputs
		.stage1_stalled(stage1_stalled),
		.stage1_PC_en(PC_en_stage1),
		.stage2_PC_en(PC_en_stage2),
		
		//inst_mem_rd_addr directly wired from datapath to inst mem
		.inst_mem_rd_en(inst_mem_rd_en),
		.PC_sel(PC_sel_stage0),
		.PC_en(PC_en_stage0)
);

decode_compute1_stage1 stage1(
	.clk(clk),
	.rst(rst),
	
	.stage2_A_en(A_en_stage2),
	.stage2_X_en(X_en_stage2),
	.stage3_A_en(A_en_stage3),
	.stage3_X_en(X_en_stage3),
	
	//Expected to be registered in previous stage
	.opcode(opcode),
	
	.B_sel(B_sel),
	.addr_sel(addr_sel),
	
	//These are the signals used in stage2
	.ALU_sel_decoded(ALU_sel_stage1),
	.jmp_type(jmp_type), //PC_sel can only be determined in stage 2 when ALU flags are ready
	.PC_en_decoded(PC_en_stage1), 
	.packet_mem_rd_en_decoded(packet_mem_rd_en_stage1), 
	.transfer_sz_decoded(transfer_sz_stage1),
	.regfile_sel_decoded(regfile_sel_stage1), 
	.regfile_wr_en_decoded(regfile_wr_en_stage1),
	
	//These are the signals used in stage3
	//(stage 3 expects these to be registered in stage2)
	.A_sel_decoded(A_sel_stage1), 
	.A_en_decoded(A_en_stage1), 
	.X_sel_decoded(X_sel_stage1), 
	.X_en_decoded(X_en_stage1),
	
	//Stall logic outputs
	.stage1_stalled(stage1_stalled)
);

compute2_stage2 stage2 (
	.clk(clk),
	.rst(rst),
	
	//Other inputs to this module
	//ALU flags
	.eq(eq),
	.gt(gt),
	.ge(ge),
	.set(set),
	
	//Values from stage1	
	.ALU_sel_in(ALU_sel_stage1),
	.jmp_type(jmp_type), //PC_sel can only be determined in stage 2 when ALU flags are ready
	.PC_en_in(PC_en_stage1), 
	.packet_mem_rd_en_in(packet_mem_rd_en_stage1), 
	.transfer_sz_in(transfer_sz_stage1),
	.regfile_sel_in(regfile_sel_stage1), 
	.regfile_wr_en_in(regfile_wr_en_stage1),
	
	.A_sel_in(A_sel_stage1),
	.A_en_in(A_en_stage1),
	.X_sel_in(X_sel_stage1),
	.X_en_in(X_en_stage1),
	
	//This stage's outputs
	.ALU_sel(ALU_sel),
	.PC_sel(PC_sel), 
	.PC_en(PC_en), 
	.packet_mem_rd_en(packet_mem_rd_en), 
	.transfer_sz(transfer_sz),
	.regfile_sel(regfile_sel), 
	.regfile_wr_en(regfile_wr_en),
	
	//These are the signals used in stage3
	//(stage 3 expects these to be registered here)
	.A_sel_decoded(A_sel_stage2), 
	.A_en_decoded(A_en_stage2), 
	.X_sel_decoded(X_sel_stage2), 
	.X_en_decoded(X_en_stage2)
);

writeback_stage3 stage3 (
	.clk(clk),
	.rst(rst),
	
	//Values from stage2
	.A_sel_in(A_sel_stage2),
	.A_en_in(A_en_stage2),
	.X_sel_in(X_sel_stage2),
	.X_en_in(X_en_stage2),
	
	//This stage's outputs
	.A_sel(A_sel),
	.A_en(A_en),
	.X_sel(X_sel),
	.X_en(X_en)
);
endmodule
