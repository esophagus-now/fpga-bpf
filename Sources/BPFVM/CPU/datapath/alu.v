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


module alu(
    input wire [31:0] A,
    input wire [31:0] B,
    input wire [3:0] ALU_sel,
    output reg [31:0] ALU_out,
    output wire set,
    output wire eq,
    output wire gt,
    output wire ge
);

always @(ALU_sel, A, B) begin
    case (ALU_sel)
        4'h0:
            ALU_out <= A + B;
        4'h1:
            ALU_out <= A - B;
        4'h2:
            //ALU_out <= A * B; //TODO: what if this takes >1 clock cycle?
            ALU_out <= 32'hCAFEDEAD; //For simplicity, return an "error code" to say "modulus not supported"
        4'h3:
        	/*
            ALU_out <= A / B; //TODO: what if B is zero?
                              //TODO: what if this takes >1 clock cycle?
            */
            ALU_out <= 32'hDEADBEEF; //For simplicity, return an "error code" to say "division not supported"
        4'h4:
            ALU_out <= A | B;
        4'h5:
            ALU_out <= A & B;
        4'h6:
            ALU_out <= A << B; //TODO: does this work?
        4'h7:
            ALU_out <= A >> B; //TODO: does this work?
        4'h8:
            ALU_out <= ~A;
        4'h9:
        	/*
            ALU_out <= A % B; //TODO: what if B is zero?
                              //TODO: what if this takes >1 clock cycle?
            */
            ALU_out <= 32'hBEEFCAFE; //For simplicity, return an "error code" to say "modulus not supported"
        4'hA:
            ALU_out <= A ^ B;
        default:
            ALU_out <= 32'd0;
    endcase
end

//These are used as the predicates for JMP instructions
assign eq = (A == B) ? 1'b1 : 1'b0;
assign gt = (A > B) ? 1'b1 : 1'b0;
assign ge = gt | eq;
assign set = ((A & B) != 32'h00000000) ? 1'b1 : 1'b0;

endmodule
