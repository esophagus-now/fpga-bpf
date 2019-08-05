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

`define CODE_ADDR_WIDTH 10
`define CODE_DATA_WIDTH 64 
`define PACKET_BYTE_ADDR_WIDTH 12
`define PACKET_ADDR_WIDTH (`PACKET_BYTE_ADDR_WIDTH - 2)
`define PACKET_DATA_WIDTH 32

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

initial begin
	//Quick-n-dirty test program:
	/*
	LD #10  -> {16'h0000, 8'h0, 8'h0, 32'd10}
	LDX #3  -> {16'h0001, 8'h0, 8'h0, 32'd3}
	ADD X   -> {16'h000C, 8'h0, 8'h0, 32'h0}
	JA -2   -> {16'h0005, 8'h0, 8'h0, 32'hFFFFFFFE}
	*/
	DUT.instruction_memory.myram.data[0] <= {16'h0000, 8'h0, 8'h0, 32'd10};
	DUT.instruction_memory.myram.data[1] <= {16'h0001, 8'h0, 8'h0, 32'd3};
	DUT.instruction_memory.myram.data[2] <= {16'h000C, 8'h0, 8'h0, 32'h0};
	DUT.instruction_memory.myram.data[3] <= {16'h0005, 8'h0, 8'h0, 32'hFFFFFFFE};
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
	
	//Pretend the snooper has filled a packet
	@(negedge clk);
	snooper_done <= 1;
	@(negedge clk);
	snooper_done <= 0;
	
	#200
	$finish;
end

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
