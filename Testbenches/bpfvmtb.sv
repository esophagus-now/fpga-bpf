`timescale 1ns / 1ps
/*
bpfvmtb.sv

A testbench for the bpfvm block diagram. Sadly, I don't know how to properly add
a block diagram into a repo. So, for the time being, I'll describe what it is:

Simply put, the bpfvm_datapath and bpfvm_ctrl are wired together in the obvious
way (i.e. connect matching signal names). Then, instantiate one packetmem and one
codemem, and connect the memory read inputs to the remaining outputs of the datapath
and controller. Finally, make all the memory write inputs (aswell as clock and rest)
external.
*/

/*
First, a bunch of defines to make the code easier to deal with.
These were taken from the BPF reference implementation, and
modified to match Verilog's syntax
*/
/* instruction classes */
`ifndef BPF_LD
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
//Return register select
`define		RET_IMM		2'b00
`define		RET_X		2'b01
`define		RET_A		2'b10

`define CODE_ADDR_WIDTH 10
`define CODE_DATA_WIDTH 64 
`define PACKET_BYTE_ADDR_WIDTH 12
`define PACKET_ADDR_WIDTH (`PACKET_BYTE_ADDR_WIDTH - 2)
`define PACKET_DATA_WIDTH 32

`endif

module bpfvmtb();

reg rst;
reg clk;

//Interface to an external module which will fill codemem
reg [`CODE_ADDR_WIDTH-1:0] code_mem_wr_addr;
reg [`CODE_DATA_WIDTH-1:0] code_mem_wr_data;
reg code_mem_wr_en;

//Interface to snooper
reg [`PACKET_ADDR_WIDTH-1:0] snooper_wr_addr;
reg [31:0] snooper_wr_data; //Hardcoded to 32 bits. TODO: change this to 64?
reg snooper_wr_en;
reg snooper_done; //NOTE: this must be a 1-cycle pulse.
wire ready_for_snooper;

//Interface to forwarder
reg [`PACKET_ADDR_WIDTH-1:0] forwarder_rd_addr;
wire [63:0] forwarder_rd_data;
reg forwarder_rd_en;
reg forwarder_done; //NOTE: this must be a 1-cycle pulse.
wire ready_for_forwarder;

task snoopwr;
input [31:0] dat;
begin
	wait(clk == 0);
	snooper_wr_en = 1;
	snooper_wr_data = dat;
	@(negedge clk);
	snooper_wr_en = 0;
	snooper_wr_addr = snooper_wr_addr + 1;
end
endtask

initial begin
// Old quick-n-dirty test program
/*
DUT.instruction_memory.myram.data[0] <= {16'h0000, 8'h0, 8'h0, 32'd10};
DUT.instruction_memory.myram.data[1] <= {16'h0001, 8'h0, 8'h0, 32'd3};
DUT.instruction_memory.myram.data[2] <= {16'h000C, 8'h0, 8'h0, 32'h0};
DUT.instruction_memory.myram.data[3] <= {16'h0005, 8'h0, 8'h0, 32'hFFFFFFFE};
*/

	DUT.instruction_memory.myram.data[0] <= {8'h0, `BPF_ABS, `BPF_H, `BPF_LD, 8'h88, 8'h88, 32'd12}; //ldh [12]
	DUT.instruction_memory.myram.data[1] <= {8'b0, 3'b001, 2'b00, 3'b101, 8'd0, 8'd13, 32'h800}; //jeq #0x800 jt 2 jf 15
	DUT.instruction_memory.myram.data[2] <= {8'h0, `BPF_ABS, `BPF_B, `BPF_LD, 8'h88, 8'h88, 32'd23}; //ldb [23]
	DUT.instruction_memory.myram.data[3] <= {8'h0, `BPF_JEQ, `BPF_IMM, `BPF_JMP, 8'd0, 8'd11, 32'h0006}; //jeq #0x6 jt 4 jf 15
	DUT.instruction_memory.myram.data[4] <= {8'h0, `BPF_ABS, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd20}; //ldh [20]
	DUT.instruction_memory.myram.data[5] <= {8'h0, `BPF_JSET, `BPF_IMM, `BPF_JMP, 8'd9, 8'd0, 32'h1FFF}; //jset 0x1FFF jt 15 jf 6
	DUT.instruction_memory.myram.data[6] <= {8'h0, `BPF_MSH, `BPF_IMM, `BPF_LDX, 8'h0, 8'h0, 32'd14}; //ldx_msh addr 14
	DUT.instruction_memory.myram.data[7] <= {8'h0, `BPF_IND, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd14}; //ldh ind x+14
	DUT.instruction_memory.myram.data[8] <= {8'h0, `BPF_JEQ, `BPF_IMM, `BPF_JMP, 8'd0, 8'd2, 32'h0064}; //jeq 0x64 jt 9 jf 11
	DUT.instruction_memory.myram.data[9] <= {8'h0, `BPF_IND, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd16}; //ldh ind x+16
	DUT.instruction_memory.myram.data[10] <= {8'h0, `BPF_JEQ, `BPF_IMM, `BPF_JMP, 8'd3, 8'd4, 32'h00C8}; //jeq 0xC8 jt 14 jf 15
	DUT.instruction_memory.myram.data[11] <= {8'h0, `BPF_JEQ, `BPF_IMM, `BPF_JMP, 8'd0, 8'd3, 32'h00C8}; //jeq 0xC8 jt 12 jf 15
	DUT.instruction_memory.myram.data[12] <= {8'h0, `BPF_IND, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd16}; //ldh ind x+16
	DUT.instruction_memory.myram.data[13] <= {8'h0, `BPF_JEQ, `BPF_IMM, `BPF_JMP, 8'd0, 8'd1, 32'h0064}; //jeq 0x64 jt 14 jf 15
	DUT.instruction_memory.myram.data[14] <= {8'h0, 3'b0, `RET_IMM,   `BPF_RET, 8'd0, 8'd0, 32'd65535}; //ret #65535
	DUT.instruction_memory.myram.data[15] <= {8'h0, 3'b0, `RET_IMM,   `BPF_RET, 8'd0, 8'd0, 32'd0}; //ret #0
	

	clk <= 0;
	rst <= 0;
	code_mem_wr_addr <= 0;
	code_mem_wr_data <= 0;
	code_mem_wr_en <= 0;
	
	snooper_wr_addr <= 0;
	snooper_wr_data <= 0;
	snooper_wr_en <= 0;
	snooper_done <= 0;
	
	forwarder_rd_addr <= 0;
	forwarder_rd_en <= 0;
	forwarder_done <= 0;
	
	snoopwr(32'hDEADBEEF);
	snoopwr(32'hBEEFCAFE);
	snoopwr(32'hCAFEDEAD);
	snoopwr(32'h01234567);
	snoopwr(32'h89ABCDEF);
	snoopwr(32'h55555555);
	snoopwr(32'hAAAAAAAA);
	snoopwr(32'h00000000);
	snoopwr(32'h11111111);
	snoopwr(32'h22222222);
	snoopwr(32'hFFFFFFFF);
	
	//Pretend the snooper has filled a packet
	@(negedge clk);
	snooper_done <= 1;
	@(negedge clk);
	snooper_done <= 0;
	
	wait(DUT.cpu_acc | DUT.cpu_rej);
	#20
	$finish;
end

//initial #1000 $finish;

always #4 clk <= ~clk;

bpfvm DUT (
	//TODO: add proper reset signal handling
	.rst(rst),
	.clk(clk),
	//Interface to an external module which will fill codemem
	.code_mem_wr_addr(code_mem_wr_addr),
	.code_mem_wr_data(code_mem_wr_data),
	.code_mem_wr_en(code_mem_wr_en),
    
    //Interface to snooper
	.snooper_wr_addr(snooper_wr_addr),
	.snooper_wr_data(snooper_wr_data), //Hardcoded to 32 bits. TODO: change this to 64?
	.snooper_wr_en(snooper_wr_en),
	.snooper_done(snooper_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_snooper(ready_for_snooper),
    
	//Interface to forwarder
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder)
);
endmodule

//Quick-n-dirty test program:
/*
LD #10  -> {16'h0000, 8'h0, 8'h0, 32'd10}
LDX #3  -> {16'h0001, 8'h0, 8'h0, 32'd3}
ADD X   -> {16'h000C, 8'h0, 8'h0, 32'h0}
JA -2   -> {16'h0005, 8'h0, 8'h0, 32'hFFFFFFFE}
DUT.instruction_memory.myram.data[0] <= {16'h0000, 8'h0, 8'h0, 32'd10};
DUT.instruction_memory.myram.data[1] <= {16'h0001, 8'h0, 8'h0, 32'd3};
DUT.instruction_memory.myram.data[2] <= {16'h000C, 8'h0, 8'h0, 32'h0};
DUT.instruction_memory.myram.data[3] <= {16'h0005, 8'h0, 8'h0, 32'hFFFFFFFE};
*/