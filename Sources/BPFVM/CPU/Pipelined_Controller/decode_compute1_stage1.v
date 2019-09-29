`timescale 1ns / 1ps
/*
decode_compute1_stage1.v

This implements the controller for stage 1.

Control signals used:
B_sel
addr_sel

This module is stalled if any of these conditions hold:
A_en is 1 in stage2 AND our opcode is JMP or ALU or ST or TAX or RETA
A_en is 1 in stage 3 AND our opcode is JMP or ALU or STX or TXA or RETX
X_en is 1 in stage 2 AND our opcode is JMP or ALU AND our B_sel is X
X_en is 1 in stage 3 AND our opcode is JMP or ALU AND our B_sel is X
X_en is 1 in stage 2 AND our opcode is JMP or ALU AND our addr_sel is X
X_en is 1 in stage 3 AND our opcode is JMP or ALU AND our addr_sel is X


This module can stall stage0, and outputs these values to signal it:
stage1_stalled
our PC_en
*/



/*
First, a bunch of defines to make the code easier to deal with.
These were taken from the BPF reference implementation, and
modified to match Verilog's syntax
*/
`include "bpf_defs.vh" 

//I use logic to mean "it's combinational, but Verilog forces me to use reg"
`define logic reg

module decode_compute1_stage1(
	input wire clk,
	input wire rst,
	
	input wire stage2_A_en,
	input wire stage2_X_en,
	input wire stage3_A_en,
	input wire stage3_X_en,
	
	//Expected to be registered in previous stage
	input wire [15:0] opcode,
	
	output wire B_sel,
	output wire addr_sel,
	
	//These are the signals used in stage2
	output wire ALU_sel_decoded,
	output wire [2:0] jmp_type, //PC_sel can only be determined in stage 2 when ALU flags are ready
	output wire PC_en_decoded, 
	output `logic packet_mem_rd_en_decoded, 
	output wire transfer_sz_decoded,
	output wire regfile_sel_decoded, 
	output wire regfile_wr_en_decoded,
	
	//These are the signals used in stage3
	//(stage 3 expects these to be registered in stage2)
	output `logic A_sel_decoded, 
	output `logic A_en_decoded, 
	output `logic X_sel_decoded, 
	output `logic X_en_decoded,
	
	//Stall logic outputs
	output wire stage1_stalled
	//PC_en, but it's already in the outputs
);

//These are named subfields of the opcode
wire [2:0] opcode_class;
assign opcode_class = opcode[2:0];
wire [2:0] addr_type;
assign addr_type = opcode[7:5];
wire [2:0] jmp_type_internal;
assign jmp_type_internal = opcode[6:4];
wire [4:0] miscop;
assign miscop = opcode[7:3];
wire [1:0] retval;
assign retval = opcode[4:3];

//Figure out if we are "stalled" (which doesn't actually do anything besides output 
//a stalled signal to stop stage0 doing anything)

//Helpful intermediate values
wire miscop_is_zero;
assign miscop_is_zero = (miscop == 2'b00);
wire is_TAX_instruction;
assign is_TAX_instruction = (opcode_class == `BPF_MISC) && (miscop_is_zero);
wire is_TXA_instruction;
assign is_TXA_instruction = (opcode_class == `BPF_MISC) && (!miscop_is_zero);
wire is_RETA_instruction;
assign is_RETA_instruction = (opcode_class == `BPF_RET) && (retval == `RET_A);
wire is_RETX_instruction;
assign is_RETX_instruction = (opcode_class == `BPF_RET) && (retval == `RET_X);

wire we_read_A; 
assign we_read_A = (opcode_class == `BPF_ALU) || (opcode_class == `BPF_JMP) || (opcode_class == `BPF_ST) || (is_RETA_instruction) || (is_TAX_instruction);
wire we_read_X;
assign we_read_X = (opcode_class == `BPF_STX) || (is_RETX_instruction) || (is_TXA_instruction);

assign stage1_stalled = (we_read_A && (stage2_A_en || stage3_A_en)) || (we_read_X && (stage2_X_en || stage3_X_en));

//COMPUTE1 (outputs from this stage)

assign B_sel = opcode[3];
assign addr_sel = (addr_type == `BPF_IND) ? `PACK_ADDR_IND : `PACK_ADDR_ABS;

//DECODE (pre-compute outputs from future stages)

//Outputs for stage2
assign ALU_sel_decoded = opcode[7:4];
assign jmp_type = jmp_type_internal; //PC_sel can only be determined in stage2
assign transfer_sz_decoded = opcode[4:3]; 
assign PC_en_decoded = (opcode_class == `BPF_JMP);

//packet_mem_rd_en
always @(*) begin
	if ((opcode_class == `BPF_LD) && (addr_type == `BPF_ABS || addr_type == `BPF_IND)) begin
		packet_mem_rd_en_decoded <= 1;
	end else if ((opcode_class == `BPF_LDX) && (addr_type == `BPF_ABS || addr_type == `BPF_IND || addr_type == `BPF_MSH)) begin
		packet_mem_rd_en_decoded <= 1;
	end else begin
		packet_mem_rd_en_decoded <= 0;
	end
end

assign regfile_sel_decoded = (opcode_class == `BPF_STX) ? `REGFILE_IN_X : `REGFILE_IN_A;
assign regfile_wr_en_decoded = (opcode_class == `BPF_ST || opcode_class == `BPF_STX);

//Outputs for stage3
always @(*) begin
	//A_sel and A_en
	if (opcode_class == `BPF_LD) begin
		A_en_decoded <= 1;
		case (addr_type)
			`BPF_ABS, `BPF_IND:
				A_sel_decoded <= `A_SEL_PACKET_MEM;
			`BPF_IMM:
				A_sel_decoded <= `A_SEL_IMM;
			`BPF_MEM:
				A_sel_decoded <= `A_SEL_MEM;
			`BPF_LEN:
				A_sel_decoded <= `A_SEL_LEN;
			default:
				A_sel_decoded <= 0; //Error
		endcase
	end else if (opcode_class == `BPF_ALU) begin
		A_en_decoded <= 1;
		A_sel_decoded <= `A_SEL_ALU;
	end else if (is_TXA_instruction) begin
		A_en_decoded <= 1;
		A_sel_decoded <= `A_SEL_X;
	end else begin
		A_en_decoded <= 0;
		A_sel_decoded <= 0; //Don't synthesize a latch
	end
	
	//X_sel and X_en
	if (opcode_class == `BPF_LDX) begin
		X_en_decoded <= 1;
		case (addr_type)
			`BPF_ABS, `BPF_IND:
				X_sel_decoded <= `X_SEL_PACKET_MEM;
			`BPF_IMM:
				X_sel_decoded <= `X_SEL_IMM;
			`BPF_MEM:
				X_sel_decoded <= `X_SEL_MEM;
			`BPF_LEN:
				X_sel_decoded <= `X_SEL_LEN;
			`BPF_MSH:
				X_sel_decoded <= `X_SEL_MSH;
			default:
				X_sel_decoded <= 0; //Error
		endcase
	end else if (is_TAX_instruction) begin 
		X_en_decoded <= 1;
		X_sel_decoded <= `X_SEL_A;
	end else begin
		X_en_decoded <= 0;
		X_sel_decoded <= 0; //Don't synthesize a latch
	end
end

endmodule
