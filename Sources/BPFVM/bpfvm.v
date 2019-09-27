`timescale 1ns / 1ps
/*
bpfvm.v

Wires up the BPF CPU core (bpfcpu.v) with instruction and packet memory.

*/

`define PACKET_DATA_WIDTH (2**(3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH))
//God what a mess... need to fix the packet length soon!
`define PLEN_WIDTH (SNOOP_FWD_ADDR_WIDTH+1)
 
module bpfvm # (
    parameter CODE_ADDR_WIDTH = 10, // codemem depth = 2^CODE_ADDR_WIDTH
    parameter PACKET_BYTE_ADDR_WIDTH = 12, // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    parameter SNOOP_FWD_ADDR_WIDTH = 9,
    //this makes the data width of the snooper and fwd equal to:
    // 2^{3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH}
	parameter PESSIMISTIC = 0
)(
	input wire rst,
	input wire clk,
	//Interface to an external module which will fill codemem
    input wire [CODE_ADDR_WIDTH-1:0] code_mem_wr_addr,
    input wire [63:0] code_mem_wr_data, //instructions always 64 bits wide
    input wire code_mem_wr_en,
    
    //Interface to snooper
    input wire [SNOOP_FWD_ADDR_WIDTH-1:0] snooper_wr_addr,
	input wire [`PACKET_DATA_WIDTH-1:0] snooper_wr_data,
	input wire snooper_wr_en,
	input wire snooper_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_snooper,
    
	//Interface to forwarder
	input wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data,
	input wire forwarder_rd_en,
	input wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_forwarder,
	output wire [`PLEN_WIDTH-1:0] len_to_forwarder
);

//Wires from codemem to/from CPU
wire [CODE_ADDR_WIDTH-1:0] inst_rd_addr;
wire [63:0] inst_mem_data;
wire inst_mem_rd_en;

//Wires from packetmem to/from CPU
wire [31:0] cpu_rd_data; //Hardcoded to 32 bits
wire [PACKET_BYTE_ADDR_WIDTH-1:0] cpu_byte_rd_addr;
wire cpu_rd_en;
wire [1:0] transfer_sz;
wire ready_for_cpu;
wire cpu_acc;
wire cpu_rej;
wire [`PLEN_WIDTH-1:0] len_to_cpu; //TODO: fix this terrible packet length logic
	
bpfcpu # (
	.CODE_ADDR_WIDTH(CODE_ADDR_WIDTH),
	.PACKET_BYTE_ADDR_WIDTH(PACKET_BYTE_ADDR_WIDTH),
	.SNOOP_FWD_ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH),
	.PESSIMISTIC(PESSIMISTIC)
) theCPU (
	.rst(rst),
	.clk(clk),
	.mem_ready(ready_for_cpu),
	.packet_len(len_to_cpu),
	.packet_mem_rd_en(cpu_rd_en),
	.inst_mem_rd_en(inst_mem_rd_en),
	.inst_mem_data(inst_mem_data),
	.packet_data(cpu_rd_data),
	.packet_addr(cpu_byte_rd_addr),
	.inst_rd_addr(inst_rd_addr),
	.transfer_sz(transfer_sz),
	.cpu_acc(cpu_acc),
	.cpu_rej(cpu_rej)
);

packetmem # (
	.PACKET_BYTE_ADDR_WIDTH(PACKET_BYTE_ADDR_WIDTH),
	.SNOOP_FWD_ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH)
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
	.cpu_rej(cpu_rej), //NOTE: this must be a 1-cycle pulse.
	.cpu_acc(cpu_acc), //NOTE: this must be a 1-cycle pulse.
	.ready_for_cpu(ready_for_cpu),
	.len_to_cpu(len_to_cpu),
	
	//Interface to forwarder
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder),
	.len_to_forwarder(len_to_forwarder)
);

codemem # (
    .ADDR_WIDTH(CODE_ADDR_WIDTH)
) instruction_memory (
	.clk(clk),
	.wr_addr(code_mem_wr_addr),
	.wr_data(code_mem_wr_data),
	.wr_en(code_mem_wr_en),
	.rd_addr(inst_rd_addr),
	.rd_data(inst_mem_data),
	.rd_en(inst_mem_rd_en)
);

endmodule

`undef PACKET_DATA_WIDTH
`undef PLEN_WIDTH