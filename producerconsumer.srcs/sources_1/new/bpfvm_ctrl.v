`timescale 1ns / 1ps
/*

bpfvm_ctrl.v

Note: I told Vivado to use the SystemVerilog compiler for this. I'm just causing myself
a headache, aren't I?

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
    input wire zero,
    //input wire [31:0] packet_addr,
    //input wire [31:0] PC
    output logic [3:0] state_out //just to see it in the schematic
    );

//These are named subfields of the opcode
wire [2:0] opcode_class;
assign opcode_class = opcode[2:0];
wire [1:0] transfer_sz;
assign transfer_sz = opcode[4:3];
wire [3:0] alu_sel;

//State encoding. Does Vivado automatically re-encode these for better performance?
enum logic[3:0] {fetch, s2, s3, s4} dummy;

reg [1:0] state; //This should be big enough
logic [1:0] next_state;
initial begin
    state <= fetch;
end

always @(posedge clk) begin
    //TODO: reset logic
    state <= next_state;
end
    
always @(*) begin
	//Some quick dumb test to make sure I understand FSMs
	case (state)
		fetch:
			//Ah, this is why next_state needs to be made "reg".
			next_state = s2;
		s2:
			next_state = s3;
		s3:
			next_state = s4;
		s4:
			next_state = fetch;
	endcase
end    

assign state_out = state;

endmodule
