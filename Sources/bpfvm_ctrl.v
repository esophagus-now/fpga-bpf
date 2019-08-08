`timescale 1ns / 1ps
/*

bpfvm_ctrl.v

This implements a finite state machine that correctly twiddles the
datapath's select and enable lines depending on the instruction. It
assumes that the code and packet memories have single-cycle access.

This attempts to write the same controller in a different style, which
Vivado will possibly like more.

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
`define		A_SEL_PACKET_MEM 3'b001
// I noticed that both these selections do the same thing
//`define		A_SEL_ABS	3'b001
//`define		A_SEL_IND	3'b010 
`define		A_SEL_MEM	3'b011
`define		A_SEL_LEN	3'b100
`define		A_SEL_MSH	3'b101
`define		A_SEL_ALU	3'b110
`define		A_SEL_X		3'b111
//Named constants for X register MUX
`define		X_SEL_IMM 	3'b000 
`define		X_SEL_PACKET_MEM 3'b001
// I noticed that both these selections do the same thing
//`define		X_SEL_ABS	3'b001
//`define		X_SEL_IND	3'b010 
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
//Compare-to value select
`define		BPF_COMP_IMM	1'b0
`define 	BPF_COMP_X		1'b1
//PC value select
`define		PC_SEL_PLUS_1	2'b00
`define		PC_SEL_PLUS_JT	2'b01
`define		PC_SEL_PLUS_JF	2'b10
`define		PC_SEL_PLUS_IMM	2'b11
//Return register select
`define		RET_IMM		2'b00
`define		RET_X		2'b01
`define		RET_A		2'b10

//I use "logic" where I intend a combinational signal, but I need to
//use reg to make Verilog's compiler happy
`define logic reg

`define STATE_WIDTH 4 //This should be big enough

module bpfvm_ctrl(
    input wire rst,
    input wire clk,
    output `logic [2:0] A_sel,
    output `logic [2:0] X_sel,
    output `logic [1:0] PC_sel,
    output `logic addr_sel,
    output `logic A_en,
    output `logic X_en,
    output `logic PC_en,
    output `logic PC_rst,
    output wire B_sel,
    output wire [3:0] ALU_sel,
    output wire [31:0] packet_len, //Hardcoded to 32 bits
    output `logic regfile_wr_en,
    output `logic regfile_sel,
    input wire [15:0] opcode,
    input wire set,
    input wire eq,
    input wire gt,
    input wire ge,
    output `logic packet_mem_rd_en,
    output wire inst_mem_rd_en,
    output wire [1:0] transfer_sz, //TODO: should this be in the datapath instead?
    input wire mem_ready, //Signal from packetmem.v; tells CPU when to start
    input wire A_is_zero,
    input wire X_is_zero,
    input wire imm_is_zero,
    output reg accept,
    output reg reject
    );

//These are named subfields of the opcode
wire [2:0] opcode_class;
assign opcode_class = opcode[2:0];
wire [2:0] addr_type;
assign addr_type = opcode[7:5];
//wire [1:0] transfer_sz;
assign transfer_sz = opcode[4:3]; 
//wire B_sel;
assign B_sel = opcode[3];
//wire [3:0] alu_sel;
assign ALU_sel = opcode[7:4];
//TODO: quadruple-check encodings match properly in the alu module
wire [2:0] jmp_type;
assign jmp_type = opcode[6:4];
wire [4:0] miscop;
assign miscop = opcode[7:3];
wire [1:0] retval;
assign retval = opcode[4:3];

reg [4:0] delay_count; //TODO: replace this with better logic
//This is used to wait for the ALU to finish long operations

//State encoding. Does Vivado automatically re-encode these for better performance?
parameter 	fetch = 0, decode = 1, write_mem_to_A = 2, write_mem_to_X = 3,
			write_ALU_to_A = 4, msh_write_mem_to_X = 5, reset = (2**`STATE_WIDTH-1); 

reg [`STATE_WIDTH-1:0] state;
initial state = reset; //NOTE: likely to not synthesize correctly
`logic [`STATE_WIDTH-1:0] next_state;

reg [`STATE_WIDTH-1:0] dest_state_after_countdown;

always @(posedge clk) begin
    //TODO: reset logic
    if (rst) state <= reset;
    else state <= next_state;
end

//A_en
always @(*) begin
	if (
		(state == decode && (
			 (opcode_class == `BPF_LD && (
			 	addr_type == `BPF_IMM ||
			 	addr_type == `BPF_MEM ||
			 	addr_type == `BPF_LEN
			 )) ||
			 (opcode_class == `BPF_MISC && miscop != 0)
		)) ||
		(state == write_mem_to_A) ||
		(state == write_ALU_to_A)
	) begin 
		A_en <= 1'b1;
	end else begin
		A_en <= 1'b0;
	end
end

//A_sel
always @(*) begin
	if (state == write_mem_to_A) begin
		A_sel <= `A_SEL_PACKET_MEM;
	end else if (state == write_ALU_to_A) begin
		A_sel <= `A_SEL_ALU;
	end else if (state == decode) begin
		if (opcode_class == `BPF_LD) begin
			if (addr_type == `BPF_IMM) begin
				A_sel <= `A_SEL_IMM;
			end else if (addr_type == `BPF_MEM) begin
				A_sel <= `A_SEL_MEM;
			end else if (addr_type == `BPF_LEN) begin
				A_sel <= `A_SEL_LEN;
			end else begin
				A_sel <= 0;
			end
		end else if (opcode_class == `BPF_MISC && miscop != 0) begin
			A_sel <= `A_SEL_X;
		end else begin
			A_sel <= 0;
		end
	end else begin
		A_sel <= 0;
	end
end

//X_en
always @(*) begin
	if (
		(state == decode && (
			 (opcode_class == `BPF_LDX && (
			 	addr_type == `BPF_IMM ||
			 	addr_type == `BPF_MEM ||
			 	addr_type == `BPF_LEN
			 )) ||
			 (opcode_class == `BPF_MISC && miscop == 0)
		)) ||
		(state == write_mem_to_X) ||
		(state == msh_write_mem_to_X)
	) begin 
		X_en <= 1'b1;
	end else begin
		X_en <= 1'b0;
	end
end

//X_sel
always @(*) begin
	if (state == write_mem_to_X) begin
		X_sel <= `X_SEL_PACKET_MEM;
	end else if (state == msh_write_mem_to_X) begin
		X_sel <= `X_SEL_MSH;
	end else if (state == decode) begin
		if (opcode_class == `BPF_LDX) begin
			if (addr_type == `BPF_IMM) begin
				X_sel <= `X_SEL_IMM;
			end else if (addr_type == `BPF_MEM) begin
				X_sel <= `X_SEL_MEM;
			end else if (addr_type == `BPF_LEN) begin
				X_sel <= `X_SEL_LEN;
			end else begin
				X_sel <= 0;
			end
		end else if (opcode_class == `BPF_MISC && miscop == 0) begin
			X_sel <= `X_SEL_A;
		end else begin
			X_sel <= 0;
		end
	end else begin
		X_sel <= 0;
	end
end

//PC_en
always @(*) begin
	if (state == fetch || (
			state == decode && opcode_class == `BPF_JMP)
	) begin
		PC_en <= 1;
	end else begin
		PC_en <= 0;
	end
end

//PC_sel
always @(*) begin
	if (state == fetch) begin
		PC_sel <= `PC_SEL_PLUS_1;
	end else if (state == decode && opcode_class == `BPF_JMP) begin
		if (jmp_type == `BPF_JA) begin
			PC_sel <= `PC_SEL_PLUS_IMM;
		end else if (
			(jmp_type == `BPF_JEQ && eq) ||
			(jmp_type == `BPF_JGT && gt) ||
			(jmp_type == `BPF_JGE && ge) ||
			(jmp_type == `BPF_JSET && set)
		) begin
			PC_sel <= `PC_SEL_PLUS_JT;
		end else begin
			PC_sel <= `PC_SEL_PLUS_JF;
		end
	end else begin 
		PC_sel <= 0;
	end
end

//PC_rst
always @(*) begin
	if (state == reset) begin
		PC_rst <= 1'b1;
	end else begin
		PC_rst <= 0;
	end
end

//regfile_wr_en
always @(*) begin
	if (state == decode && (
			opcode_class == `BPF_ST ||
			opcode_class == `BPF_STX
		)
	) begin
		regfile_wr_en <= 1'b1;
	end else begin
		regfile_wr_en <= 1'b0;
	end
end

//packet_mem_rd_en
always @(*) begin
	if (state == decode) begin
		if (opcode_class == `BPF_LD && (
				addr_type == `BPF_ABS ||
				addr_type == `BPF_IND
			)
		) begin
			packet_mem_rd_en <= 1;
		end else if (opcode_class == `BPF_LDX && (
				addr_type == `BPF_ABS ||
				addr_type == `BPF_IND ||
				addr_type == `BPF_MSH
			)
		) begin
			packet_mem_rd_en <= 1;
		end else begin
			packet_mem_rd_en <= 0;
		end
	end else begin
		packet_mem_rd_en <= 0;
	end
end

//inst_mem_rd_en
assign inst_mem_rd_en = (state == fetch);

//accept/reject
always @(*) begin
	if (state == decode && opcode_class == `BPF_RET) begin
		if (
			(retval == `RET_IMM && !imm_is_zero) ||
			(retval == `RET_X && !X_is_zero) ||
			(retval == `RET_A && !A_is_zero)
		) begin
			accept <= 1;
			reject <= 0;
		end else begin
			reject <= 1;
			accept <= 0;
		end
	end else begin
		accept <= 0;
		reject <= 0;
	end
end

//addr_sel
always @(*) begin
	if (addr_type == `BPF_IND) begin
		addr_sel <= `PACK_ADDR_IND;
	end else begin
		addr_sel <= `PACK_ADDR_ABS;
	end
end

//regfile_sel
always @(*) begin
	if (opcode_class == `BPF_STX) begin
		regfile_sel <= `REGFILE_IN_X;
	end else begin
		regfile_sel <= `REGFILE_IN_A;
	end
end

//next state

always @(*) begin
	case (state)
		reset: begin
			if (mem_ready && (!rst)) next_state <= fetch;
			else next_state <= reset;
		end fetch: begin
			next_state <= decode; //Need to wait a cycle for memory read
		end decode: begin
			case (opcode_class)
				`BPF_LD: begin 
					//Does this use the immediate, packet memory, scratch memory, or length?
					if (
						(addr_type == `BPF_IMM) ||
						(addr_type == `BPF_MEM) ||
						(addr_type == `BPF_LEN) 
					) begin
						next_state <= fetch;
					end else if (
						(addr_type == `BPF_ABS) ||
						(addr_type == `BPF_IND)
					) begin
						next_state <= write_mem_to_A;
					end else begin
						//This is an error
						next_state <= reset;
					end
				end `BPF_LDX: begin
					if (
						(addr_type == `BPF_IMM) ||
						(addr_type == `BPF_MEM) ||
						(addr_type == `BPF_LEN) 
					) begin
						next_state <= fetch;
					end else if (
						(addr_type == `BPF_ABS) ||
						(addr_type == `BPF_IND)
					) begin
						next_state <= write_mem_to_X;
					end else if (addr_type == `BPF_MSH) begin
						next_state <= msh_write_mem_to_X;
					end else begin
						//This is an error
						next_state <= reset;
					end
					
				end `BPF_ST, `BPF_STX, `BPF_JMP, `BPF_MISC: begin 
					next_state <= fetch;
				end `BPF_ALU: begin
					next_state <= write_ALU_to_A;
				end `BPF_RET: begin
					next_state <= reset;
				end default: begin
					next_state <= reset; //ERROR!
				end
			endcase
		end write_mem_to_A, write_ALU_to_A, write_mem_to_X, msh_write_mem_to_X: begin
			next_state <= fetch;
		end default: begin
			//ERROR
			next_state <= reset;
		end
	endcase
end    

assign packet_len = 0; //TODO: update this when I figure out where to get the info

endmodule
