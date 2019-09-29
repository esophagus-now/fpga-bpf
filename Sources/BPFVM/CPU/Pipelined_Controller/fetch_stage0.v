`timescale 1ns / 1ps
/*
fetch_stage0.v

This implements the controller for stage 0.

Control signals used:
inst_mem_rd_en
PC_en
PC_sel

This module is stalled if any of these conditions hold:
PC_en is 1 in stage1
PC_en is 1 in stage2
stage1 is stalled

This module cannot stall other modules
*/

//RULING ON THE FIELD: outputs from different modules are combined using boolean OR. 
//For example, both stage0 and stage2 have a PC_en outputs; they are OR'ed together
//to form the final PC_en output

module fetch_stage0(
	input wire clk,
	input wire rst,
	
	//Stall logic inputs
	input wire stage1_stalled,
	input wire stage1_PC_en,
	input wire stage2_PC_en,
	
	//inst_mem_rd_addr directly wired from datapath to inst mem
	output wire inst_mem_rd_en,
	output wire [1:0] PC_sel,
	output wire PC_en
);

wire good2go = ~(stage1_stalled || stage1_PC_en || stage2_PC_en);


//Surprisingly, this is all we need
assign inst_mem_rd_en = good2go;
assign PC_sel = (good2go) ? `PC_SEL_PLUS_1 : 2'b0;
assign PC_en = good2go;

endmodule
