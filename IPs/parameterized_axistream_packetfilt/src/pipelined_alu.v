`timescale 1ns / 1ps
/*

alu.v

A simple pipelined ALU with the following "schedule". It has an II of 1.

C0: (Input: A, B; Output: none)
All the operations are computed and stored in a regsiter
The flags are computed and stored in a register

C1: (Input: ALU_sel; Output: eq, gt, ge, set)
The flags are now valid
The ALU_out register is filled by MUXing all the ops

C2: (Input: none; Output: ALU_out)
The ALU_out is ready

This module is instantiated as part of pipelined_bpfvm_datapath. 

BIZARRE PIPELINING DECISION:
Instead of reading ALU_sel in C0 (and buffering it for one cycle) I choose to read it
in C1. That means that, to use this ALU with an II of 1, you do this:

t = 0:
Write A[0] and B[0]

t = 1:
Write ALU_sel[0]
Write A[1] and B[1]

t = 2:
Read ALU_out[0]
Write ALU_sel[1]
Write A[2] and B[2]

...

t = n:
Read ALU_out[n-2]
Write ALU_sel[n-1]
Write A[n] and B[n]

IMPORTANT (AND QUESTIONABLE) DESIGN DECISION:
This ALU does not support any multi-cycle instructions. That is, there is no multiple,
divide, or mod. First, I did this ti ismplify the design. And second, I doubt that many
programs would need this anyway.  However, I may end up putting it in sometime in the 
future.
*/


module pipelined_alu # (
	parameter PESSIMISTIC = 0
)(
	input wire clk,
    input wire [31:0] A,
    input wire [31:0] B,
    input wire [3:0] ALU_sel,
    output wire [31:0] ALU_out,
    output wire set,
    output wire eq,
    output wire gt,
    output wire ge
);


reg [31:0] add_r = 0; 
always @(posedge clk) add_r <= A + B;

reg [31:0] sub_r = 0; 
always @(posedge clk) sub_r <= A - B;

reg [31:0] or_r = 0; 
always @(posedge clk) or_r <= A | B;

reg [31:0] and_r = 0; 
always @(posedge clk) and_r <= A & B;

reg [31:0] lsh_r = 0; 
always @(posedge clk) lsh_r <= A << B;

reg [31:0] rsh_r = 0; 
always @(posedge clk) rsh_r <= A >> B;

reg [31:0] not_r = 0; 
always @(posedge clk) not_r <= ~A;

reg [31:0] xor_r = 0; 
always @(posedge clk) xor_r <= A ^ B;

reg [31:0] ALU_out_r;
always @(posedge clk) begin
    case (ALU_sel)
        4'h0:
            ALU_out_r <= add_r;
        4'h1:
            ALU_out_r <= sub_r;
        4'h2:
            //ALU_out <= A * B; //TODO: what if this takes >1 clock cycle?
            ALU_out_r <= 32'hCAFEDEAD; //For simplicity, return an "error code" to say "modulus not supported"
        4'h3:
        	/*
            ALU_out <= A / B; //TODO: what if B is zero?
                              //TODO: what if this takes >1 clock cycle?
            */
            ALU_out_r <= 32'hDEADBEEF; //For simplicity, return an "error code" to say "division not supported"
        4'h4:
            ALU_out_r <= or_r;
        4'h5:
            ALU_out_r <= and_r;
        4'h6:
            ALU_out_r <= lsh_r; //TODO: does this work?
        4'h7:
            ALU_out_r <= rsh_r; //TODO: does this work?
        4'h8:
            ALU_out_r <= not_r;
        4'h9:
        	/*
            ALU_out <= A % B; //TODO: what if B is zero?
                              //TODO: what if this takes >1 clock cycle?
            */
            ALU_out_r <= 32'hBEEFCAFE; //For simplicity, return an "error code" to say "modulus not supported"
        4'hA:
            ALU_out_r <= xor_r;
        default:
            ALU_out_r <= 32'd0;
    endcase
end

assign ALU_out = ALU_out_r;

wire eq_internal, gt_internal, ge_internal, set_internal;

//These are used as the predicates for JMP instructions
assign eq_internal = (A == B) ? 1'b1 : 1'b0;
assign gt_internal = (A > B) ? 1'b1 : 1'b0;
assign ge_internal = gt_internal | eq_internal;
assign set_internal = ((A & B) != 32'h00000000) ? 1'b1 : 1'b0;

reg eq_r, gt_r, ge_r, set_r;
always @(posedge clk) begin
	eq_r <= eq_internal;
	gt_r <= gt_internal;
	ge_r <= ge_internal;
	set_r <= set_internal;
end
assign eq = eq_r;
assign gt = gt_r;
assign ge = ge_r;
assign set = set_r;


endmodule
