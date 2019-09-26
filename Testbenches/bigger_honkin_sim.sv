`timescale 1ns / 1ps
/*
bigger_honkin_sim.sv

This is the same thing as big_honkin_sim, but tests if 128-bit wide snooping and forwarding
work properly, and instantiates the parallel packet filter

This testbenche's purpose is to wire up a snooper and forwarder into the BPFVM, and generate
some fake data for the snooper to look at. The general idea is to see that packets are 
correctly accepted/rejected, correctly forwarded out, and to get an idea on performance.
*/

`include "../Sources/bpf_defs.vh" 

`define CODE_ADDR_WIDTH 10
`define CODE_DATA_WIDTH 64 
`define PACKET_BYTE_ADDR_WIDTH 12
`define PACKET_ADDR_WIDTH (`PACKET_BYTE_ADDR_WIDTH - 4)
`define PACKET_DATA_WIDTH 128

module bigger_honkin_sim();
reg clk;
reg rst;

//Interface to an external module which will fill codemem
reg [`CODE_ADDR_WIDTH-1:0] code_mem_wr_addr;
reg [`CODE_DATA_WIDTH-1:0] code_mem_wr_data;
reg code_mem_wr_en;

//Interface from BPFVM to snooper
wire [`PACKET_ADDR_WIDTH-1:0] snooper_wr_addr;
wire [`PACKET_DATA_WIDTH-1:0] snooper_wr_data; 
wire snooper_wr_en;
wire snooper_done; //NOTE: this must be a 1-cycle pulse.
wire ready_for_snooper;

//Interface from BPFVM to forwarder
wire [`PACKET_ADDR_WIDTH-1:0] forwarder_rd_addr;
wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data;
wire forwarder_rd_en;
wire forwarder_done; //NOTE: this must be a 1-cycle pulse.
wire ready_for_forwarder;
wire [`PACKET_ADDR_WIDTH+1-1:0] len_to_forwarder;

//AXI Stream interface into snooper
reg [`PACKET_DATA_WIDTH-1:0] snoop_tdata;
reg snoop_tvalid;
reg snoop_tready;
reg snoop_tlast;

//AXI Stream interface out of forwarder
wire [`PACKET_DATA_WIDTH-1:0] TDATA;
wire TVALID;
wire TLAST;
reg TREADY;

integer fd;

task codewr;
input [63:0] dat;
begin
	wait(clk == 0);
	code_mem_wr_en = 1;
	code_mem_wr_data = dat;
	@(negedge clk);
	code_mem_wr_en = 0;
	code_mem_wr_addr = code_mem_wr_addr + 1;
end
endtask

event fill_code_mem, fill_code_mem_done;

initial forever begin
	@(fill_code_mem);
	
	code_mem_wr_addr = 0;
	
	codewr({8'h0, `BPF_ABS, `BPF_H, `BPF_LD, 8'h88, 8'h88, 32'd12}); //ldh [12]                         
	codewr({8'b0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd13, 32'h800}); //jeq #0x800 jt 2 jf 15    
	codewr({8'h0, `BPF_ABS, `BPF_B, `BPF_LD, 8'h88, 8'h88, 32'd23}); //ldb [23]                         
	codewr({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd11, 32'h0006}); //jeq #0x6 jt 4 jf 15     
	codewr({8'h0, `BPF_ABS, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd20}); //ldh [20]                           
	codewr({8'h0, `BPF_JSET, `BPF_COMP_IMM, `BPF_JMP, 8'd9, 8'd0, 32'h1FFF}); //jset 0x1FFF jt 15 jf 6  
	codewr({8'h0, `BPF_MSH, `BPF_B, `BPF_LDX, 8'h0, 8'h0, 32'd14}); //ldxb_msh addr 14                  
	codewr({8'h0, `BPF_IND, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd14}); //ldh ind x+14                       
	codewr({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd2, 32'h0064}); //jeq 0x64 jt 9 jf 11      
	codewr({8'h0, `BPF_IND, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd16}); //ldh ind x+16                       
	codewr({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd3, 8'd4, 32'h00C8}); //jeq 0xC8 jt 14 jf 15    
	codewr({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd3, 32'h00C8}); //jeq 0xC8 jt 12 jf 15    
	codewr({8'h0, `BPF_IND, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd16}); //ldh ind x+16                      
	codewr({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd1, 32'h0064}); //jeq 0x64 jt 14 jf 15    
	codewr({8'h0, 3'b0, `RET_IMM,   `BPF_RET, 8'd0, 8'd0, 32'd65535}); //ret #65535                    
	codewr({8'h0, 3'b0, `RET_IMM,   `BPF_RET, 8'd0, 8'd0, 32'd0}); //ret #0                            

	->fill_code_mem_done;
end

event start_snoop;
event done_processing;

integer packets_left = 0;

initial begin
	//Initial values for reg variables
	clk <= 0;
	rst <= 1; //Trigger a reset
	
	code_mem_wr_addr <= 0;
	code_mem_wr_data <= 0;
	code_mem_wr_en <= 0;
	
	snoop_tdata <= 0;
	snoop_tvalid <= 0;
	snoop_tready <= 0;
	snoop_tlast <= 0;
	
	TREADY <= 1;
	
	//Read in the drivers
	fd = $fopen("bigger_honkin_test_data.mem", "r"); //TODO: fill this file
	while($fgetc(fd) != "\n") begin end //Skip first line of comments
	
	//Wait a few clock cycles before de-asserting rst
	#20
	rst <= 0;
	
	//It almost seems like the BRAM "isn't ready yet". So let's try waiting a few clock cycles while we do nothing
	repeat (20) @(negedge clk);
	
	->fill_code_mem;
	@(fill_code_mem_done);
	
	->start_snoop;
	
	@(done_processing);
	#40
	$finish;
end

always #5 clk <= ~clk;

initial begin
	@(start_snoop);
	forever begin 
		@(posedge clk);
		if (!$feof(fd)) begin
			$fscanf(fd, "%h%b%b%b", snoop_tdata, snoop_tvalid, snoop_tready, snoop_tlast);
		end 
	end
end

always @(posedge clk) begin
	if (snooper_done) packets_left++;
	if (PF.VMs[0].the_VM.cpu_rej) packets_left--;
	if (forwarder_done) packets_left--;
	if (packets_left == 0 && $feof(fd)) ->done_processing;
end

parallel_packetfilts # (
    .CODE_ADDR_WIDTH(`CODE_ADDR_WIDTH), // codemem depth = 2^CODE_ADDR_WIDTH
    .PACKET_BYTE_ADDR_WIDTH(`PACKET_BYTE_ADDR_WIDTH), // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    .SNOOP_FWD_ADDR_WIDTH(`PACKET_ADDR_WIDTH),
    .N(5)
) PF (
	.rst(rst),
	.axi_aclk(clk),
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
axistream_snooper # (
	.DATA_WIDTH(`PACKET_DATA_WIDTH),
	.ADDR_WIDTH(`PACKET_ADDR_WIDTH)
) el_snoopo (
	.clk(clk),
	.TDATA(snoop_tdata),
	.TVALID(snoop_tvalid),
	.TREADY(snoop_tready),
	.TLAST(snoop_tlast),
	
	//Interface to packet mem
	.wr_addr(snooper_wr_addr),
	.wr_data(snooper_wr_data),
	.mem_ready(ready_for_snooper),
	.wr_en(snooper_wr_en),
	.done(snooper_done)
);

axistream_forwarder # (
	.DATA_WIDTH(`PACKET_DATA_WIDTH),
	.ADDR_WIDTH(`PACKET_ADDR_WIDTH)
) forward_unto_dawn(
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
