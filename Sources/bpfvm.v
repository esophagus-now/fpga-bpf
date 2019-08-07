`timescale 1ns / 1ps
/*
bpfvm.v

Wires up the BPF CPU core (bpfcpu.v) with instruction and packet memory.

*/

//TODO: Fix this
`define CODE_ADDR_WIDTH 10
`define CODE_DATA_WIDTH 64 
`define PACKET_BYTE_ADDR_WIDTH 12
`define PACKET_ADDR_WIDTH (`PACKET_BYTE_ADDR_WIDTH - 2)
`define PACKET_DATA_WIDTH 32

module bpfvm(
	//TODO: add proper reset signal handling
	input wire rst,
	input wire clk,
	//Interface to an external module which will fill codemem
    input wire [`CODE_ADDR_WIDTH-1:0] code_mem_wr_addr,
    input wire [`CODE_DATA_WIDTH-1:0] code_mem_wr_data,
    input wire code_mem_wr_en,
    
    //Interface to snooper
    input wire [`PACKET_ADDR_WIDTH-1:0] snooper_wr_addr,
	input wire [31:0] snooper_wr_data, //Hardcoded to 32 bits. TODO: change this to 64?
	input wire snooper_wr_en,
	input wire snooper_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_snooper,
    
	//Interface to forwarder
	input wire [`PACKET_ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [63:0] forwarder_rd_data,
	input wire forwarder_rd_en,
	input wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_forwarder
);

//Wires from codemem to/from CPU
wire [`CODE_ADDR_WIDTH-1:0] inst_rd_addr;
wire [`CODE_DATA_WIDTH-1:0] inst_mem_data;
wire inst_mem_rd_en;

//Wires from packetmem to/from CPU
wire [31:0] cpu_rd_data; //Hardcoded to 32 bits
wire [`PACKET_BYTE_ADDR_WIDTH-1:0] cpu_byte_rd_addr;
wire cpu_rd_en;
wire [1:0] transfer_sz;
wire ready_for_cpu;
wire cpu_acc;
wire cpu_rej;
	
bpfcpu # (
	.CODE_ADDR_WIDTH(`CODE_ADDR_WIDTH),
	.CODE_DATA_WIDTH(`CODE_DATA_WIDTH),
	.PACKET_BYTE_ADDR_WIDTH(`PACKET_BYTE_ADDR_WIDTH),
	.PACKET_ADDR_WIDTH(`PACKET_ADDR_WIDTH),
	.PACKET_DATA_WIDTH(`PACKET_DATA_WIDTH)
) theCPU (
	.rst(rst),
	.clk(clk),
	.mem_ready(ready_for_cpu),
	.packet_mem_rd_en(cpu_rd_en),
	.inst_mem_rd_en(inst_mem_rd_en),
	.inst_mem_data(inst_mem_data),
	.packet_data(cpu_rd_data),
	.packet_addr(cpu_byte_rd_addr),
	.inst_rd_addr(inst_rd_addr),
	.transfer_sz(transfer_sz),
	.accept(cpu_acc),
	.reject(cpu_rej)
);

codemem # (
    .ADDR_WIDTH(`CODE_ADDR_WIDTH),
    .DATA_WIDTH(`CODE_DATA_WIDTH)
) instruction_memory (
	.clk(clk),
	.wr_addr(code_mem_wr_addr),
	.wr_data(code_mem_wr_data),
	.wr_en(code_mem_wr_en),
	.rd_addr(inst_rd_addr),
	.rd_data(inst_mem_data),
	.rd_en(inst_mem_rd_en)
);

packetmem # (
    .ADDR_WIDTH(`PACKET_ADDR_WIDTH) 
) packmem (
	.clk(clk),
	.p3ctrl_rst(rst),
	
	//Interface to snooper
	.snooper_wr_addr(snooper_wr_addr),
	.snooper_wr_data(snooper_wr_data),
	.snooper_wr_en(snooper_wr_en),
	.snooper_done(snooper_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_snooper(ready_for_snooper),
	
	//Interface to CPU
	.cpu_byte_rd_addr(cpu_byte_rd_addr),
	.transfer_sz(transfer_sz),
	.cpu_rd_data(cpu_rd_data),
	.cpu_rd_en(cpu_rd_en),
	.cpu_rej(cpu_rej),
	.cpu_acc(cpu_acc), //NOTE: this must be a 1-cycle pulse.
	.ready_for_cpu(ready_for_cpu),
	
	//Interface to forwarder
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder)
);

endmodule
