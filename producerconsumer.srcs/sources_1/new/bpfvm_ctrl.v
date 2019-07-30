`timescale 1ns / 1ps
/*

bpfvm_ctrl.v

Note: I told Vivado to use the SystemVerilog compiler for this. I'm just causing myself
a headache, aren't I?

This (unfinished, some would say unstarted) module implements the FSM that drives the
BPF processor. Most of its outputs control the bpfvm_dapath module.

*/

/*
First, a bunch of defines to make the code easier to deal with.
These were taken from the BPF reference implementation, and
modified to match Verilog's syntax
*/
/* instruction classes */
`define		BPF_LD		3'b000
`define		BPF_LDX		3'b001
`define		BPF_ST		3'b010
`define		BPF_STX		3'b011
`define		BPF_ALU		3'b100
`define		BPF_JMP		3'b101
`define		BPF_RET		3'b110
`define		BPF_MISC	3'b111

/* ld/ldx fields */
//Fetch size 
`define		BPF_W		2'b00 //Word, half-word, and byte
`define		BPF_H		2'b01
`define		BPF_B		2'b10
//Addressing mode
`define		BPF_IMM 	3'b000 
`define		BPF_ABS		3'b001
`define		BPF_IND		3'b010 
`define		BPF_MEM		3'b011
`define		BPF_LEN		3'b100
`define		BPF_MSH		3'b101
//Named constants for A register MUX
`define		A_SEL_IMM 	3'b000 
`define		A_SEL_ABS	3'b001
`define		A_SEL_IND	3'b010 
`define		A_SEL_MEM	3'b011
`define		A_SEL_LEN	3'b100
`define		A_SEL_MSH	3'b101
`define		A_SEL_ALU	3'b110
`define		A_SEL_X		3'b111
//Named constants for X register MUX
`define		X_SEL_IMM 	3'b000 
`define		X_SEL_ABS	3'b001
`define		X_SEL_IND	3'b010 
`define		X_SEL_MEM	3'b011
`define		X_SEL_LEN	3'b100
`define		X_SEL_MSH	3'b101
`define		X_SEL_A		3'b111
//Absolute or indirect address select
`define		PACK_ADDR_ABS	1'b0
`define		PACK_ADDR_IND	1'b1
//A or X select for regfile write
`define		REGFILE_IN_A	1'b0
`define		REGFILE_IN_X	1'b1
//ALU operand B select
`define		ALU_B_SEL_IMM	1'b0
`define		ALU_B_SEL_X		1'b1
//ALU operation select
`define		BPF_ADD		4'b0000
`define		BPF_SUB		4'b0001
`define		BPF_MUL		4'b0010
`define		BPF_DIV		4'b0011
`define		BPF_OR		4'b0100
`define		BPF_AND		4'b0101
`define		BPF_LSH		4'b0110
`define		BPF_RSH		4'b0111
`define		BPF_NEG		4'b1000
`define		BPF_MOD		4'b1001
`define		BPF_XOR		4'b1010
//Jump types
`define		BPF_JA		3'b000
`define		BPF_JEQ		3'b001
`define		BPF_JGT		3'b010
`define		BPF_JGE		3'b011
`define		BPF_JSET	3'b100
//PC value select
`define		PC_SEL_PLUS_1	2'b00
`define		PC_SEL_PLUS_JT	2'b01
`define		PC_SEL_PLUS_JF	2'b10
`define		PC_SEL_PLUS_IMM	2'b11

module bpfvm_ctrl(
    input wire rst,
    input wire clk,
    output logic [2:0] A_sel,
    output logic [2:0] X_sel,
    output logic [1:0] PC_sel,
    output logic addr_sel,
    output logic A_en,
    output logic X_en,
    output logic IR_en,
    output logic PC_en,
    output logic PC_rst,
    output logic B_sel,
    output logic [3:0] ALU_sel,
    //output wire [63:0] inst_mem_data,
    //output wire [63:0] packet_data, //This will always get padded to 64 bits
    output wire [63:0] packet_len,
    output logic regfile_wr_en,
    output logic regfile_sel,
    input wire [15:0] opcode,
    input wire set,
    input wire eq,
    input wire gt,
    input wire ge,
    //input wire [31:0] packet_addr,
    //input wire [31:0] PC
    output logic [3:0] state_out, //just to see it in the schematic
    output logic packet_mem_rd_en,
    output logic inst_mem_rd_en,
    output logic [1:0] transfer_sz //TODO: should this be in the datapath instead?
    );

//These are named subfields of the opcode
wire [2:0] opcode_class;
assign opcode_class = opcode[2:0];
wire [2:0] addr_type;
assign addr_type = opcode[7:5];
//wire [1:0] transfer_sz;
assign transfer_sz = opcode[4:3]; //TODO: fix packetmem so the encodings work properly
//wire B_sel;
assign B_sel = opcode[3];
//wire [3:0] alu_sel;
assign ALU_sel = opcode[7:4];
//TODO: quadruple-check encodings match properly in the alu module
wire [2:0] jmp_type;
assign jmp_type = opcode[6:4];
wire [4:0] miscop;
assign miscop = opcode[7:3];

reg [4:0] delay_count; //TODO: replace this with better logic
//This is used to wait for the ALU to finish long operations

//State encoding. Does Vivado automatically re-encode these for better performance?
enum logic[3:0] {fetch, decode, write_to_A, write_to_X, countdown} dest_state_after_countdown;

reg [3:0] state; //This should be big enough
initial state = fetch;
logic [1:0] next_state;

always @(posedge clk) begin
    //TODO: reset logic
    state <= next_state;
end
    
always @(*) begin
	{A_en, X_en, IR_en, PC_en, PC_rst,
	regfile_wr_en, packet_mem_rd_en, 
	inst_mem_rd_en} = 0;	//Reset "dangerous" control bus lines to 0
							//Note the use of the blocking assignment
	case (state)
		fetch: begin
			PC_sel = `PC_SEL_PLUS_1; //Select PC+1
			PC_en = 1'b1;   //Update PC
			inst_mem_rd_en = 1'b1; //Enable reading from memory
			
			next_state = decode; //Need to wait a cycle for memory read
		end decode: begin
			//I called this state "decode" to keep it short, but in reality
			//this does decoding AND the first clock cycle of the instruction
			case (opcode_class)
				/**/`BPF_LD: begin 
					//Does this use the immediate, packet memory, scratch memory, or length?
					if (addr_type == `BPF_IMM) begin //immediate
						A_sel = `A_SEL_IMM;
						A_en = 1'b1;
						
						next_state = fetch;
					end else if (addr_type == `BPF_MEM) begin //scratch memory
						//Note that datapath already takes care of regfile address
						A_sel = `A_SEL_MEM;
						A_en = 1'b1;
						
						next_state = fetch; //We can get away with this because I'm using
						//distributed RAM ("asynchronous" reads) in the register file
						//That is, I don't need to wait a clock cycle for the data to be
						//ready.
					end else if (addr_type == `BPF_LEN) begin
						A_sel = `A_SEL_LEN;
						A_en = 1'b1;
						
						next_state = fetch;
					end else if (addr_type == `BPF_ABS) begin //packet memory, absolute addressing
						addr_sel = `PACK_ADDR_ABS;
						packet_mem_rd_en = 1'b1;
						//transfer size already taken care of
						
						next_state = write_to_A;
					end else if (addr_type == `BPF_IND) begin //packet memory, indirect addressing
						addr_sel = `PACK_ADDR_IND;
						packet_mem_rd_en = 1'b1;
						//transfer size already taken care of
						
						next_state = write_to_A;
					end else begin
						//This is an error
						next_state = fetch;
					end
					
				end `BPF_LDX: begin //LDX
					//Does this use the immediate, packet memory, scratch memory, or length?
					if (addr_type == `BPF_IMM) begin //immediate
						X_sel = `X_SEL_IMM;
						X_en = 1'b1;
						
						next_state = fetch;
					end else if (addr_type == `BPF_MEM) begin //scratch memory
						//Note that datapath already takes care of regfile address
						X_sel = `X_SEL_MEM;
						X_en = 1'b1;
						
						next_state = fetch; //We can get away with this because I'm using
						//distributed RAM ("asynchronous" reads) in the register file
						//That is, I don't need to wait a clock cycle for the data to be
						//ready.
					end else if (addr_type == `BPF_LEN) begin
						X_sel = `X_SEL_LEN;
						X_en = 1'b1;
						
						next_state = fetch;
					end else if (addr_type == `BPF_ABS) begin //packet memory, absolute addressing
						addr_sel = `PACK_ADDR_ABS;
						packet_mem_rd_en = 1'b1;
						//transfer size already taken care of
						
						next_state = write_to_X;
					end else if (addr_type == `BPF_IND) begin //packet memory, indirect addressing
						addr_sel = `PACK_ADDR_IND;
						packet_mem_rd_en = 1'b1;
						//transfer size already taken care of
						
						next_state = write_to_X;
					end else begin
						//This is an error
						next_state = fetch;
					end
				
				end `BPF_ST: begin //ST
					//scratch_mem[imm] = A
					regfile_wr_en = 1'b1;
					regfile_sel = `REGFILE_IN_A;
					//Note that datapath already takes care of regfile address
					
					next_state = fetch;
				end `BPF_STX: begin //STX
					//scratch_mem[imm] = X
					regfile_wr_en = 1'b1;
					regfile_sel = `REGFILE_IN_X;
					//Note that datapath already takes care of regfile address
					
					next_state = fetch;
				end `BPF_ALU: begin //ALU
					//Here we have A op= [X|K], with the exception of the NOT operator
					//It so happens that ALU_sel and B_sel are already taken care of.
					//The only thing I really want to do now is make sure enough clock
					//cycles go by.
					A_sel = `A_SEL_ALU;
					
					//Assume +,-,|,&,^ are single-cycle
					//Assume <<, >>, *, /, % take 32 cycles
					case (ALU_sel)
						`BPF_ADD,`BPF_SUB, `BPF_OR, `BPF_AND, `BPF_XOR:
							next_state = write_to_A;
						default: begin
							delay_count = 'd31;
							dest_state_after_countdown = write_to_A;
							
							next_state = countdown;
						end
					endcase
				end `BPF_JMP: begin //JMP
					//Except for JA, all the jump types use A and B in the ALU
					//It so happens that B is already selected correctly, ctrl-f
					//for "assign B_sel"
					
					//TODO: is the ALU ready on this clock cycle? What if I get
					//timing violations?
					if (jmp_type == `BPF_JA) begin
						PC_sel = `PC_SEL_PLUS_IMM;
					end else if (
						(jmp_type == `BPF_JEQ && eq) ||
						(jmp_type == `BPF_JGT && gt) ||
						(jmp_type == `BPF_JGE && ge) ||
						(jmp_type == `BPF_JSET && set)
					) begin
						PC_sel = `PC_SEL_PLUS_JT;
					end else begin
						PC_sel = `PC_SEL_PLUS_JF;
					end
					PC_en = 1'b1;
					
					next_state = fetch; //Is this OK?
				end `BPF_RET: begin //RET
					//TODO: figure out how BPF VM signals that a packet is accepted or not
					
					next_state = fetch;
					
				end `BPF_MISC: begin //MISC
					if (miscop == 0) begin //TAX
						X_sel = `X_SEL_A;
						X_en = 1'b1;
					end else begin //TXA
						A_sel = `A_SEL_X;
						A_en = 1'b1;
					end
					
					next_state = fetch;
				end
			endcase
			
			//I think this is also an error
			next_state = fetch;
		end write_to_A: begin
			A_en = 1'b1;
			next_state = fetch;
		end write_to_X: begin
			X_en = 1'b1;
			next_state = fetch;
		end countdown: begin
			//This is used to wait for long ALU operations
			delay_count--;
			if (delay_count == 0) begin
				next_state = dest_state_after_countdown;
			end
		end
	endcase
end    

assign state_out = state;
assign packet_len = 0; //TODO: update this when I figure out where to get the info

endmodule
