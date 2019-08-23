`timescale 1ns / 1ps
/*

bpfvm_ctrl.v

This implements a finite state machine that correctly twiddles the datapath's myriad 
select and enable lines depending on the instruction. It assumes that the code and 
packet memories have single-cycle access.

This file is actually an overhaul of the original "switch statement" FSM. Now it splits
each output and the next state logic into separate always blocks. This had a pretty decent
imporvement on the synthesized result.

*/

/*
First, a bunch of defines to make the code easier to deal with.
These were taken from the BPF reference implementation, and
modified to match Verilog's syntax
*/
`include "../../bpf_defs.vh" 

//I use "logic" where I intend a combinational signal, but I need to
//use reg to make Verilog's compiler happy
`define logic reg

`define STATE_WIDTH 4 //This should be wide enough

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

assign transfer_sz = opcode[4:3]; 

assign B_sel = opcode[3];

assign ALU_sel = opcode[7:4];

wire [2:0] jmp_type;
assign jmp_type = opcode[6:4];
wire [4:0] miscop;
assign miscop = opcode[7:3];
wire [1:0] retval;
assign retval = opcode[4:3];

//State encoding. Does Vivado automatically re-encode these for better performance?
parameter 	fetch = 0, decode = 1, write_mem_to_A = 2, write_mem_to_X = 3,
			write_ALU_to_A = 4, msh_write_mem_to_X = 5, reset = (2**`STATE_WIDTH-1); 

reg [`STATE_WIDTH-1:0] state;
initial state = reset; //NOTE: likely to not synthesize correctly
`logic [`STATE_WIDTH-1:0] next_state;

reg [`STATE_WIDTH-1:0] dest_state_after_countdown;

always @(posedge clk) begin
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
					//Check if we're using immediate, packet memory, scratch memory, or length
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

endmodule
