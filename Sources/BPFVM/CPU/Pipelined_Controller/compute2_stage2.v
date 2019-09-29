`timescale 1ns / 1ps
/*
decode_compute1_stage2.v

This implements the controller for stage 2.

Control signals used:
ALU_sel
PC_sel
PC_en
packet_mem_rd_en
transfer_s
regfile_sel
regfile_wr_en

This module will never be stalled

This module can stall stage0, and outputs these values to signal it:
our PC_en

This module can stall stage1, and outputs these values to signal it:
our A_en
out X_en
*/

`include "bpf_defs.vh" 

//I use logic where Verilog syntax forces me to use reg, but I mean to
//use a combinational signal
`define logic reg

module compute2_stage2(
	input clk,
	input rst,
	
	//Other inputs to this module
	//ALU flags
	input wire eq,
	input wire gt,
	input wire ge,
	input wire set,
	
	//Values from stage1	
	input wire ALU_sel_in,
	input wire [2:0] jmp_type, //PC_sel can only be determined in stage 2 when ALU flags are ready
	input wire PC_en_in, 
	input wire packet_mem_rd_en_in, 
	input wire [1:0] transfer_sz_in,
	input wire regfile_sel_in, 
	input wire regfile_wr_en_in,
	input wire valid_in,
	
	input wire [2:0] A_sel_in,
	input wire A_en_in,
	input wire [2:0] X_sel_in,
	input wire X_en_in,
	
	//This stage's outputs
	output reg [3:0] ALU_sel,
	output `logic [2:0] PC_sel, 
	output reg PC_en, 
	output reg packet_mem_rd_en, 
	output reg [1:0] transfer_sz,
	output reg regfile_sel, 
	output reg regfile_wr_en,
	output reg valid,
	
	//These are the signals used in stage3
	//(stage 3 expects these to be registered here)
	output reg [2:0] A_sel_decoded, 
	output reg A_en_decoded, 
	output reg [2:0] X_sel_decoded, 
	output reg X_en_decoded
	
	//Stall logic outputs:
	//A_en, X_en, PC_en, but they're already in the outputs
);

//This stage's outputs
always @(posedge clk) begin
	ALU_sel <= ALU_sel_in;
	//PC_sel is below
	PC_en <= valid_in && PC_en_in;
	packet_mem_rd_en <= valid_in && packet_mem_rd_en_in;
	transfer_sz <= transfer_sz_in;
	regfile_sel <= regfile_sel_in;
	regfile_wr_en <= valid_in && regfile_wr_en_in;
end
//Another subtlety: PC_sel is a combinational output of the ALU flags
//and the jump type (and PC_en)
//Here I've written it with an if statement for clarity, and I hope it
//will be combinational (and no latches, Vivado!)
always @(*) begin
	//PC_sel
	if (PC_en) begin
		if (jmp_type == `BPF_JA) begin
			PC_sel <= `PC_SEL_PLUS_IMM;
		end else if ( //If conditional jump was true
			(jmp_type == `BPF_JEQ && eq) ||
			(jmp_type == `BPF_JGT && gt) ||
			(jmp_type == `BPF_JGE && ge) ||
			(jmp_type == `BPF_JSET && set)
		) begin
			PC_sel <= `PC_SEL_PLUS_JT;
		end else begin
			PC_sel <= `PC_SEL_PLUS_JF;
		end
	end else begin
		PC_sel <= 0; //Remember the rule of using logical OR to combine outputs from multiple stages
	end
end
	
//Register outputs for stage3
always @(posedge clk) begin
	A_sel_decoded <= A_sel_in;
	A_en_decoded <= A_en_in;
	X_sel_decoded <= X_sel_in;
	X_en_decoded <= X_en_in;
	valid <= valid_in;
end

endmodule
