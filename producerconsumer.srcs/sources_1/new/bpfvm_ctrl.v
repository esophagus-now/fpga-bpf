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
    input wire zero,
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
wire [3:0] alu_sel;

//State encoding. Does Vivado automatically re-encode these for better performance?
enum logic[3:0] {fetch, decode, write_to_A, write_to_X} dummy;

reg [1:0] state; //This should be big enough
initial state <= fetch;
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
			PC_sel = 2'b00; //Select PC+1
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
					//So here have A op= [X|K], with the exception of the NOT operator
					
				end `BPF_JMP: begin //JMP
				
				end `BPF_RET: begin //RET
				
				end `BPF_MISC: begin //MISC
				
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
		end
	endcase
end    

assign state_out = state;
assign packet_len = 0; //TODO: update this when I figure out where to get the info

endmodule
