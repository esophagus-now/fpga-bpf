`timescale 1ns / 1ps
/*

bpfvm_ctrl.v

This (unfinished, some would say unstarted) module implements the FSM that drives the
BPF processor. Most of its outputs control the bpfvm_dapath module.

*/


module bpfvm_ctrl(
    input wire rst,
    input wire clk,
    output wire [2:0] A_sel,
    output wire [2:0] X_sel,
    output wire [1:0] PC_sel,
    output wire addr_sel,
    output wire A_en,
    output wire X_en,
    output wire IR_en,
    output wire PC_en,
    output wire PC_rst,
    output wire B_sel,
    output wire [3:0] ALU_sel,
    //output wire [63:0] inst_mem_data,
    //output wire [63:0] packet_data, //This will always get padded to 64 bits
    output wire [63:0] packet_len,
    output wire regfile_wr_en,
    input wire [15:0] opcode,
    input wire set,
    input wire eq,
    input wire gt,
    input wire zero//,
    //input wire [31:0] packet_addr,
    //input wire [31:0] PC
    );
    
//Hmmmmm.... I'm not sure how to deal with external memory (i.e. external
//to this module)

//These are named subfields of the opcode
//This should go in the state machine, not the datapath!
wire [2:0] opcode_class;
assign opcode_class = opcode[2:0];
wire [1:0] transfer_sz;
assign transfer_sz = opcode[4:3];
wire [3:0] alu_sel;
    
endmodule
