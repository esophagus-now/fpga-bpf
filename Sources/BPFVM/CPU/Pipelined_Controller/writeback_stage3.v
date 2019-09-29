`timescale 1ns / 1ps
/*
decode_compute1_stage3.v

This implements the controller for stage 3.

Control signals used:
A_sel
A_en
X_sel
X_en

This module will never be stalled

This module can stall stage1, and outputs these values to signal it:
our A_en
out X_en
*/


module writeback_stage3(
	input wire clk,
	input wire rst,
	
	//Values from stage2
	input wire [2:0] A_sel_in,
	input wire A_en_in,
	input wire [2:0] X_sel_in,
	input wire X_en_in,
	
	//This stage's outputs
	output reg [2:0] A_sel,
	output reg A_en,
	output reg [2:0] X_sel,
	output reg X_en
	
	//Stall logic outputs:
	//A_en, X_en (but they're already outputs)
);

always @(posedge clk) begin
	A_sel <= A_sel_in;
	A_en <= A_en_in;
	X_sel <= X_sel_in;
	X_en <= X_en_in;
end
endmodule
