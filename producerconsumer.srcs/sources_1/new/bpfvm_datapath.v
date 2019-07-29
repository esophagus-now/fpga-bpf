`timescale 1ns / 1ps
/*
bpfvm_datapath.v

This implements the datapath of the BPF processor. It includes the accumulator (A)
and auXiliary (X) register as defined by the BSD Packet Filter spec. (Note: there is
no actual spec; I just looked through the C files in the libpcap git repo). It also
includes an ALU (defined in alu.v) and scratch memory (defined in regfile.v).

This file is not super easy to read; I recommend using Vivado's auto-generated
schematic (in the "Elaborated Design") to see what this file is supposed to do. 
Actually, in order to write this file, I actually drew out what I wanted then
fiddled with the verilog until the schematic matched my drawing. 

This "datapath" is intended to be controlled by the FSM defined in bpfvm_ctrl.v
*/


module bpfvm_datapath(
    input wire rst,
    input wire clk,
    input wire [2:0] A_sel,
    input wire [2:0] X_sel,
    input wire [1:0] PC_sel,
    input wire addr_sel,
    input wire A_en,
    input wire X_en,
    //input wire IR_en,
    input wire PC_en,
    input wire PC_rst,
    input wire B_sel,
    input wire [3:0] ALU_sel,
    input wire [63:0] inst_mem_data,
    input wire [63:0] packet_data, //This will always get padded to 64 bits
    input wire [63:0] packet_len,
    input wire regfile_wr_en,
    input wire regfile_sel,
    output wire [15:0] opcode,
    output wire set,
    output wire eq,
    output wire gt,
    output wire zero,
    output wire [31:0] packet_addr,
    output reg [31:0] nextPC, //This better not be a (clocked) register!
    output wire [63:0] IR, //This is just to see it in the schematic
    output wire inst_mem_RD_en, //This is just to see it in the schematic
    output wire packet_RD_en //This is just to see it in the schematic
);

reg [31:0] A, X; //A is the accumulator, X is the auxiliary register
wire [31:0] B; //ALU's second operand
wire [31:0] ALU_out;
//reg [63:0] IR;  //Instruction register
assign IR = inst_mem_data;

reg [31:0] PC = 0; //I think this is the only initial value that matters

wire [7:0] jt, jf; //These are named subfields of the IR value
wire [31:0] imm;

assign opcode = IR[63:48];
assign jt = IR[47:40];
assign jf = IR[39:32];
assign imm = IR[31:0];

wire [31:0] scratch_odata;
wire [31:0] scratch_idata;

assign scratch_idata = (regfile_sel == 1'b1) ? X : A;

//Accumulator's new value
always @(posedge clk) begin
    if (A_en == 1'b1) begin
        case (A_sel)
            3'b000:
                A <= imm;
            3'b001:
                A <= packet_data;
            3'b010:
                A <= packet_data; //Hmmmm... both ABS and IND addressing wire packet_data to A
            3'b011:
                A <= scratch_odata; 
            3'b100:
                A <= packet_len;
            3'b101:
                A <= 0; //TODO: what is that weird MSH thing?
            3'b110:
                A <= ALU_out;
            3'b111: //for TXA instruction
                A <= X;
        endcase
    end
end

//Auxiliary (X) register's new value
always @(posedge clk) begin
    if (X_en == 1'b1) begin
        case (X_sel)
            3'b000:
                X <= imm;
            3'b001:
                X <= packet_data;
            3'b010:
                X <= packet_data; //Hmmmm... both ABS and IND addressing wire packet_data to X
            3'b011:
                X <= scratch_odata;
            3'b100:
                X <= packet_len;
            /*3'b101:
                X <= 0; //TODO: what is that weird MSH thing?*/
            3'b111: //for TAX instruction
                X <= A;
            default:
                X <= 0; //Does this even make sense?
        endcase
    end
end

//Program counter's new value
always @(posedge clk) begin
    if (PC_rst == 1'b1) begin
        PC <= 0;
    end else if (PC_en == 1'b1) begin
        PC <= nextPC;
    end
end

always @(PC_sel, PC, jt, jf, imm) begin
    case (PC_sel)
        2'b00:
            nextPC <= PC + 1;
        2'b01:
            nextPC <= PC + jt; //TODO: sign-extend jt and jf?
        2'b10:
            nextPC <= PC + jf; 
        2'b11:
            nextPC <= PC + imm; //TODO: sign-extend imm? 
    endcase
end

//packet_addr mux
assign packet_addr = (addr_sel == 1'b1) ? imm : (X+imm);
//This should cover all the cases?
//TODO: figure out how to deal with variable-size fetches

//ALU operand B select
assign B = (B_sel == 1'b1) ? X : imm;

alu myalu (
    .A(A),
    .B(B),
    .ALU_sel(ALU_sel),
    .ALU_out(ALU_out),
    .zero(zero),
    .eq(eq),
    .gt(gt),
    .set(set)
    );

regfile scratchmem (
    .clk(clk),
    .addr(imm[3:0]),
    .idata(scratch_idata),
    .odata(scratch_odata),
    .wr_en(regfile_wr_en)
);



endmodule
