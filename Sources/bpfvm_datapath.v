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

//TODO: Make PC width a parameter, then do the complicated dance Xilinx forces me to
//in order to update the IP packaged from the block diagram
module bpfvm_datapath # (parameter
	CODE_ADDR_WIDTH = 10,
	CODE_DATA_WIDTH = 64,
	PACKET_BYTE_ADDR_WIDTH = 12
)(
    input wire rst,
    input wire clk,
    input wire [2:0] A_sel,
    input wire [2:0] X_sel,
    input wire [1:0] PC_sel,
    input wire addr_sel,
    input wire A_en,
    input wire X_en,
    input wire PC_en,
    input wire PC_rst,
    input wire B_sel,
    input wire [3:0] ALU_sel,
    input wire [CODE_DATA_WIDTH-1:0] inst_mem_data,
    input wire [31:0] packet_data, //This will always get padded to 32 bits
    input wire [31:0] packet_len, //Hardcoded
    input wire regfile_wr_en,
    input wire regfile_sel,
    output wire [15:0] opcode,
    output wire set,
    output wire eq,
    output wire gt,
    output wire ge,
    //TODO: Add addr width parameters
    output wire [PACKET_BYTE_ADDR_WIDTH-1:0] packet_addr,
    output reg [CODE_ADDR_WIDTH-1:0] PC = 0,
    output wire A_is_zero,
    output wire X_is_zero,
    output wire imm_is_zero
);

reg [31:0] A, X; //A is the accumulator, X is the auxiliary register
wire [31:0] B; //ALU's second operand
wire [31:0] ALU_out;
wire [CODE_DATA_WIDTH-1:0] IR;  //Instruction register
assign IR = inst_mem_data; //Note: this is just a rename

reg [CODE_ADDR_WIDTH-1:0] nextPC = 0; //This better not be a (clocked) register!

wire [7:0] jt, jf; //These are named subfields of the IR value
wire [31:0] imm;

assign opcode = IR[63:48];
assign jt = IR[47:40];
assign jf = IR[39:32];
assign imm = IR[31:0];

wire [31:0] scratch_odata;
wire [31:0] scratch_idata;

assign scratch_idata = (regfile_sel == 1'b1) ? X : A;

//Named constants for A register MUX
`ifndef A_SEL_IMM
`define		A_SEL_IMM 	3'b000
`endif 
`define		A_SEL_ABS	3'b001
`define		A_SEL_IND	3'b010 
`define		A_SEL_MEM	3'b011
`define		A_SEL_LEN	3'b100
`define		A_SEL_MSH	3'b101
`define		A_SEL_ALU	3'b110
`define		A_SEL_X		3'b111
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
                A <= {26'b0, imm[3:0], 2'b0}; //TODO: No MSH instruction is defined (by bpf) for A. Should I leave this?
            3'b110:
                A <= ALU_out;
            3'b111: //for TXA instruction
                A <= X;
        endcase
    end
end

//Named constants for X register MUX
`define		X_SEL_IMM 	3'b000 
`define		X_SEL_ABS	3'b001
`define		X_SEL_IND	3'b010 
`define		X_SEL_MEM	3'b011
`define		X_SEL_LEN	3'b100
`define		X_SEL_MSH	3'b101
`define		X_SEL_A		3'b111
//Auxiliary (X) register's new value
always @(posedge clk) begin
    if (X_en == 1'b1) begin
        case (X_sel)
            `X_SEL_IMM:
                X <= imm;
            `X_SEL_ABS:
                X <= packet_data;
            `X_SEL_IND:
                X <= packet_data; //Hmmmm... both ABS and IND addressing wire packet_data to X
            `X_SEL_MEM:
                X <= scratch_odata;
            `X_SEL_LEN:
                X <= packet_len;
            `X_SEL_MSH:
                X <= {26'b0, imm[3:0], 2'b0};
            `X_SEL_A: //for TAX instruction
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
assign packet_addr = (addr_sel == 1'b0) ? imm : (X+imm);
//This should cover all the cases?

//ALU operand B select
assign B = (B_sel == 1'b1) ? X : imm;

alu myalu (
    .A(A),
    .B(B),
    .ALU_sel(ALU_sel),
    .ALU_out(ALU_out),
    .eq(eq),
    .gt(gt),
    .ge(ge),
    .set(set)
    );

regfile scratchmem (
    .clk(clk),
    .addr(imm[3:0]),
    .idata(scratch_idata),
    .odata(scratch_odata),
    .wr_en(regfile_wr_en)
);

assign A_is_zero = (A == 0);
assign X_is_zero = (X == 0);
assign imm_is_zero = (imm == 0);

endmodule
