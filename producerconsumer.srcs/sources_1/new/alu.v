`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2019 11:08:27 AM
// Design Name: 
// Module Name: alu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module alu(
    input wire [31:0] A,
    input wire [31:0] B,
    input wire [3:0] ALU_sel,
    output reg [31:0] ALU_out,
    output wire set,
    output wire eq,
    output wire gt,
    output wire zero
);

always @(ALU_sel, A, B) begin
    case (ALU_sel)
        4'h0:
            ALU_out <= A + B;
        4'h1:
            ALU_out <= A - B;
        4'h2:
            ALU_out <= A * B; //TODO: what if this takes >1 clock cycle?
        4'h3:
            ALU_out <= A / B; //TODO: what if B is zero?
                              //TODO: what if this takes >1 clock cycle?
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
            ALU_out <= A % B; //TODO: what if B is zero?
                              //TODO: what if this takes >1 clock cycle?
        4'hA:
            ALU_out <= A ^ B;
        default:
            ALU_out <= 32'd0;
    endcase
end


assign zero = (32'b0 == A) ? 1'b1 : 1'b0;
assign eq = (A == B) ? 1'b1 : 1'b0;
assign gt = (A > B) ? 1'b1 : 1'b0;
assign set = ((A & B) != 32'h00000000) ? 1'b1 : 1'b0;

endmodule
