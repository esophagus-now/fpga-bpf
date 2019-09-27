`timescale 1ns / 1ps
/*

alu.v

A simple ALU designed to match the needs of the BPF VM. I have not confirmed if all the
operations can run in a single cycle. If they can't, I need to do a little extra work in
the bpfvm_ctrl module.

This module is instantiated as part of bpfvm_datapath. 

IMPORTANT (AND QUESTIONABLE) DESIGN DECISION:
This ALU does not support any multi-cycle instructions. That is, there is no multiple,
divide, or mod. First, I did this ti ismplify the design. And second, I doubt that many
programs would need this anyway.  However, I may end up putting it in sometime in the 
future.
*/


module alu # (
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

reg [31:0] ALU_out_internal = 0;

always @(*) begin
    case (ALU_sel)
        4'h0:
            ALU_out_internal <= A + B;
        4'h1:
            ALU_out_internal <= A - B;
        4'h2:
            //ALU_out <= A * B; //TODO: what if this takes >1 clock cycle?
            ALU_out_internal <= 32'hCAFEDEAD; //For simplicity, return an "error code" to say "modulus not supported"
        4'h3:
        	/*
            ALU_out <= A / B; //TODO: what if B is zero?
                              //TODO: what if this takes >1 clock cycle?
            */
            ALU_out_internal <= 32'hDEADBEEF; //For simplicity, return an "error code" to say "division not supported"
        4'h4:
            ALU_out_internal <= A | B;
        4'h5:
            ALU_out_internal <= A & B;
        4'h6:
            ALU_out_internal <= A << B; //TODO: does this work?
        4'h7:
            ALU_out_internal <= A >> B; //TODO: does this work?
        4'h8:
            ALU_out_internal <= ~A;
        4'h9:
        	/*
            ALU_out <= A % B; //TODO: what if B is zero?
                              //TODO: what if this takes >1 clock cycle?
            */
            ALU_out_internal <= 32'hBEEFCAFE; //For simplicity, return an "error code" to say "modulus not supported"
        4'hA:
            ALU_out_internal <= A ^ B;
        default:
            ALU_out_internal <= 32'd0;
    endcase
end

wire eq_internal, gt_internal, ge_internal, set_internal;

//These are used as the predicates for JMP instructions
assign eq_internal = (A == B) ? 1'b1 : 1'b0;
assign gt_internal = (A > B) ? 1'b1 : 1'b0;
assign ge_internal = gt_internal | eq_internal;
assign set_internal = ((A & B) != 32'h00000000) ? 1'b1 : 1'b0;

////////////////////////////////////////
////////// PESSIMISTIC MODE ////////////
////////////////////////////////////////
generate
if (PESSIMISTIC) begin
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
	
	reg [31:0] ALU_out_r;
	always @(posedge clk) begin
		ALU_out_r <= ALU_out_internal;
	end
	assign ALU_out = ALU_out_r;
end
///////////////////////////////////////
////////// OPTIMISTIC MODE ////////////
///////////////////////////////////////
else begin
	assign eq = eq_internal;
	assign gt = gt_internal;
	assign ge = ge_internal;
	assign set = set_internal;
	
	assign ALU_out = ALU_out_internal;
end
endgenerate
////////////////////////////////////////

endmodule
