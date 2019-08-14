`timescale 1ns / 1ps
/*
big_honkin_sim.sv

This testbenche's purpose is to wire up a snooper and forwarder into the BPFVM, and generate
some fake data for the snooper to look at. The general idea is to see that packets are 
correctly accepted/rejected, correctly forwarded out, and to get an idea on performance.
*/

//TODO: Fix this
`define CODE_ADDR_WIDTH 10
`define CODE_DATA_WIDTH 64 
`define PACKET_BYTE_ADDR_WIDTH 12
`define PACKET_ADDR_WIDTH (`PACKET_BYTE_ADDR_WIDTH - 2)
`define PACKET_DATA_WIDTH 32

module big_honkin_sim();
reg clk;
reg rst;

//Interface to an external module which will fill codemem
reg [`CODE_ADDR_WIDTH-1:0] code_mem_wr_addr;
reg [`CODE_DATA_WIDTH-1:0] code_mem_wr_data;
reg code_mem_wr_en;

//Interface from BPFVM to snooper
wire [`PACKET_ADDR_WIDTH-1:0] snooper_wr_addr;
wire [31:0] snooper_wr_data; //Hardcoded to 32 bits. TODO: change this to 64?
wire snooper_wr_en;
wire snooper_done; //NOTE: this must be a 1-cycle pulse.
wire ready_for_snooper;

//Interface from BPFVM to forwarder
wire [`PACKET_ADDR_WIDTH-1:0] forwarder_rd_addr;
wire [63:0] forwarder_rd_data;
wire forwarder_rd_en;
wire forwarder_done; //NOTE: this must be a 1-cycle pulse.
wire ready_for_forwarder;
wire [31:0] len_to_forwarder;

//Wires that the snooper is snooping on
reg [31:0] data;
reg strobe;

//AXI Stream interface
wire [63:0] TDATA;
wire TVALID;
wire TLAST;
reg TREADY;

integer fd;

initial begin
	//Initial values for reg variables
	clk <= 0;
	//rst <= ???;
	
	code_mem_wr_addr <= 0;
	code_mem_wr_data <= 0;
	code_mem_wr_en <= 0;
	
	data <= 0;
	strobe <= 0;
	
	TREADY <= 0;
	
	//Read in the frivers
	fd = $fopen("big_honkin_test_data.mem", "r"); //TODO: fill this file
	while($fgetc(fd) != "\n") begin end //Skip first line of comments
end

always #5 clk <= ~clk;

bpfvm VM (
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
	.ready_for_forwarder(ready_for_forwarder),
	.len_to_forwarder(len_to_forwarder)

);


//Snooper don't care what you had for dinner...
//He just snoops and snoops and snoops and snoops and snoops...
// (Snooter, Josh Woodward)

//SNOOPS I did it again!
// (Britney Spears)

//Snoooooper! You know you are a snooooooper!
// (Dreamer?)

//We come on the Snoop John B... my grandfather and me...
// (Sloop John B.)

//Snoopercalafragilisticexpialadocious...
// (Mary Poppins)

//Snooper Trooper love is gonna find me...
// (Super Trooper, ABBA)

//Snoop! There it is...
// (Space Jam theme)

//Snoop... on... me... (snoop! on! me!)
// (Take on me, A-HA)
dataval_snooper # (
	.FLITS_PER_PACKET(15) //I think this should be big enough
) el_snoopo (
	.clk(clk),
	.data(data),
	.strobe(strobe),
	
	//Interface to packet mem
	.wr_addr(snooper_wr_addr),
	.wr_data(snooper_wr_data),
	.mem_ready(ready_for_snooper),
	.wr_en(snooper_wr_en),
	.done(snooper_done)
);

axistream_forwarder forward_unto_dawn(
	.clk(clk),
	
	//AXI Stream interface
	.TDATA(TDATA),
	.TVALID(TVALID),
	.TLAST(TLAST),
	.TREADY(TREADY),	
	
	//Interface to packetmem
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder),
	.len_to_forwarder(len_to_forwarder)
);
endmodule
