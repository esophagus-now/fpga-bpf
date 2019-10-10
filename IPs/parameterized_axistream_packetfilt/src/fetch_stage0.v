`timescale 1ns / 1ps
/*
fetch_stage0.v

This implements the controller for stage 0. Its job is to handle the "instruction
register". However, for me, the instruction register is the actual output of the
code memory itself. Basically, this boils down to only enabling the mem_rd_en and
PC increment when stage1 is ready.

The valid bit is tricky. It essentially has the same logic as TDATA in an AXI Stream
circuit. Once we read the memory, it's "filled". Once stage1 is ready, the register 
is "emptied". 

Control signals used:
inst_mem_rd_en
PC_en
PC_sel

This module is stalled if any of these conditions hold:
PC_en is 1 in stage1
PC_en is 1 in stage2
stage1 is stalled

This module cannot stall other modules
*/

//RULING ON THE FIELD: outputs from different modules are combined using boolean OR. 
//For example, both stage0 and stage2 have a PC_en outputs; they are OR'ed together
//to form the final PC_en output

module fetch_stage0(
	input wire clk,
	input wire rst,
	
	//Stall logic inputs
	input wire stage1_stalled,
	input wire stage1_PC_en,
	input wire stage2_PC_en,
	
	//inst_mem_rd_addr directly wired from datapath to inst mem
	output wire inst_mem_rd_en,
	output wire [1:0] PC_sel,
	output wire PC_en,
	
	output reg valid
);

wire good2go = ~(stage1_stalled || stage1_PC_en || stage2_PC_en);

assign inst_mem_rd_en = good2go && !rst;
assign PC_sel = (good2go) ? `PC_SEL_PLUS_1 : 2'b0;
assign PC_en = good2go;

//valid_n truth table
//	good2go	|	stage1_stalled	|	valid	|	valid_n
//	0		|	0				|	0		|	d		//This shouldn't happen; stage1 should be stalled when valid is 0
//	0		|	0				|	1		|	0		//stage1 reads, and we don't write
//	0		|	1				|	0		|	0		//valid doesn't change (we don't read, and neither does stage1)
//	0		|	1				|	1		|	1		//valid doesn't change (we don't read, and neither does stage1)
//	1		|	0				|	0		|	1		//We read the next instruction
//	1		|	0				|	1		|	1		//We read the next instruction
//	1		|	1				|	0/1		|	d		//This is impossible; good2go is always 0 when stage1_stalled is 1

/*KMAP:
							valid
							0	1
{good2go,stage1_stalled} ---------
					00	|	d	0
					01	|	0	1
					11	|	d	d
					10	|	1	1

So valid_n = good2go || (valid && stage1_stalled)
As usual, now that I know the answer, it makes sense; we are valid if we
read anything new, or if we were already valid and stage1 doesn't read 
anything
*/

wire valid_n;
assign valid_n = good2go || (valid && stage1_stalled);
			

always @(posedge clk) begin
	if (rst) begin
		valid <= 0;
	end else begin
		valid <= valid_n;
	end
end

endmodule
