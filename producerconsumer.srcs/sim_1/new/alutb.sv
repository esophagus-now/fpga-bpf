`timescale 1ns / 1ps
/*

alutb.sv

I mean, do you really need to test something as simple as alu.v?

The answer is yes, since there are a million unknowns. What happens when you
divide (or modulus) by zero? Does the divide really only take one clock cycle
(which, by the way, other parts of my design depend on)? 

*/


module alutb();
reg [31:0] A;
reg [31:0] B;
reg [3:0] ALU_sel;
wire[31:0] ALU_out;
wire set;
wire eq;
wire gt;
wire zero;

//For ALU_sel values between 0 and A, the followign operations are denoted (in order):
// + - * / | & << >> ~ % ^


initial begin
    A <= $random;
    B <= 4;
    ALU_sel <= 0;
    repeat (10) begin
        #100
        ALU_sel <= ALU_sel + 1;
    end
    #100
    $finish;
end

//hey..... wait a minute.... this is only a behavioural sim
//I need a timing sim!

alu DUT(
    .A(A),
    .B(B),
    .ALU_sel(ALU_sel),
    .ALU_out(ALU_out),
    .set(set),
    .eq(eq),
    .gt(gt),
    .zero(zero)
);


endmodule
