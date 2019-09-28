`timescale 1ns / 1ps

/*
decode_compute1_stage1.v

This implements the controller for stage 1.

Control signals used:
B_sel
addr_sel

This module is stalled if any of these conditions hold:
A_en is 1 in stage2 AND our opcode is JMP or ALU
A_en is 1 in stage 3 AND our opcode is JMP or ALU
X_en is 1 in stage 2 AND our opcode is JMP or ALU AND our B_sel is X
X_en is 1 in stage 3 AND our opcode is JMP or ALU AND our B_sel is X
X_en is 1 in stage 2 AND our opcode is JMP or ALU AND our addr_sel is X
X_en is 1 in stage 3 AND our opcode is JMP or ALU AND our addr_sel is X


This module can stall stage0, and outputs these values to signal it:
stage1_stalled
our PC_en
*/

module decode_compute1_stage1(
	input wire clk,
	input wire rst,
	
	input wire stage2_A_en,
	input wire stage2_X_en,
	input wire stage3_A_en,
	input wire stage3_X_en,
	
	//Expected to be registered in previous stage
	input wire [15:0] opcode,
	
	output wire B_sel,
	output wire addr_sel,
	
	//These are the signals used in stage2
	//(stage 2 expects these to be registered here)
	output reg ALU_sel,
	output reg PC_sel,
	output reg PC_en, 
	output reg packmem_rd_en, 
	output reg regfile_sel, 
	output reg regfile_wr_en,
	
	//These are the signals used in stage3
	//(stage 3 expects these to be registered in stage2, who expects them to be registered here)
	output reg A_sel, 
	output reg A_en, 
	output reg X_sel, 
	output reg X_en,
	
	output wire stage1_valid //Do I really need this?
	
);
endmodule
