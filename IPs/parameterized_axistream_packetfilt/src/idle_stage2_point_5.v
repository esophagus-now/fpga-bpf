/*
idle_stage2_point_5.v

This implements a (pessimistic) idle stage between stages 2 and 3

Control signals used:
none

This module will never be stalled

This module can stall stage1, and outputs these values to signal it:
our A_en
out X_en
*/


module idle_stage2_point_5(
	input wire clk,
	input wire rst,
	
	//Values from stage2
	input wire [2:0] A_sel_in,
	input wire A_en_in,
	input wire [2:0] X_sel_in,
	input wire X_en_in,
	input wire valid_in,
	
	//These are the signals used in stage3, delayed here by one cycle
	output reg [2:0] A_sel,
	output reg A_en,
	output reg [2:0] X_sel,
	output reg X_en,
	
	output reg valid = 0
	//Stall logic outputs:
	//A_en, X_en (but they're already outputs)
);

always @(posedge clk) begin
	A_sel <= A_sel_in;
	A_en <= valid_in && A_en_in;
	X_sel <= X_sel_in;
	X_en <= valid_in && X_en_in;
	valid <= valid_in;
end
endmodule