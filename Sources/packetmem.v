`timescale 1ns / 1ps
/*

packetmem.v

This file is best described by a diagram available in the repo's wiki. It can
also be found under Figures/pingpangpung.png.

Essentially, instantiates three packetram modules. It also instantiates a bunch
of fiddly glue logic, including the p3ctrl module and the painfulmuxes modules 
in order to arbitrate everything.

*/

//Assumes packetram is 32 bits wide (per port)
`define DATA_WIDTH 32

module packetmem#(parameter
    ADDR_WIDTH = 10 
)(
	//TODO: add pipeline signalling
	input wire clk,
	
	//Interface to snooper
	input wire [ADDR_WIDTH-1:0] snooper_wr_addr,
	input wire [63:0] snooper_wr_data,
	input wire snooper_wr_en,
	input wire snooper_done, //NOTE: this must be a 1-cycle pulse.
	//TODO: decide whether or not to make this interface simpler
	//or to possibly do some kind of handshaking
	
	//Interface to CPU
	input wire [ADDR_WIDTH+2-1:0] cpu_byte_rd_addr,
	input wire [1:0] transfer_sz,
	output wire [32:0] cpu_rd_data,
	input wire cpu_rd_en,
	input wire cpu_rej,
	input wire cpu_acc, //NOTE: this must be a 1-cycle pulse.
	//TODO: decide whether or not to make this interface simpler
	//or to possibly do some kind of handshaking
	
	//Interface to forwarder
	input wire [ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [63:0] forwarder_rd_data,
	input wire forwarder_rd_en,
	input wire forwarder_done //NOTE: this must be a 1-cycle pulse.
	//TODO: decide whether or not to make this interface simpler
	//or to possibly do some kind of handshaking
);

//Forward declare wires for memories
wire [ADDR_WIDTH-1:0] ping_addr;
wire [2*`DATA_WIDTH-1:0] ping_do;
wire [`DATA_WIDTH-1:0] ping_di;
wire ping_wr_en;
wire ping_rd_en;

wire [ADDR_WIDTH-1:0] pang_addr;
wire [2*`DATA_WIDTH-1:0] pang_do;
wire [`DATA_WIDTH-1:0] pang_di;
wire pang_wr_en;
wire pang_rd_en;

wire [ADDR_WIDTH-1:0] pung_addr;
wire [2*`DATA_WIDTH-1:0] pung_do;
wire [`DATA_WIDTH-1:0] pung_di;
wire pung_wr_en;
wire pung_rd_en;

//Declare wires for controller stuff
wire [1:0] sn_sel, cpu_sel, fwd_sel;

//Instantiate the controller
p3_ctrl dispatcher (
	.clk(clk),
	.A_done(snooper_done),
	.B_acc(cpu_acc), //Special case for me: B can "accept" a memory buffer and send it to C
	.B_rej(cpu_rej), //or it can "reject" it and send it back to A
	.C_done(forwarder_done),
	.sn_sel(sn_sel),
	.cpu_sel(cpu_sel),
	.fwd_sel(fwd_sel)
);

//Special thing to do for CPU: apply the read size adapter
//TODO: fix these variable names, they are extremely confusing!!

wire [ADDR_WIDTH-1:0] cpu_rd_addr;
wire [2*`DATA_WIDTH-1:0] membuf_rd_data;

read_size_adapter # (
	.BYTE_ADDR_WIDTH(ADDR_WIDTH+2) 
) cpu_adapter (
	.clk(clk),
	.byte_rd_addr(cpu_byte_rd_addr),
	.transfer_sz(transfer_sz),
	.word_rd_addra(cpu_rd_addr),
	.bigword(membuf_rd_data),
	.resized_mem_data(cpu_rd_data) //zero-padded on the left (when necessary)
);

//Instantiate the crazy MUXes
painfulmuxes # (
	.ADDR_WIDTH(ADDR_WIDTH)
) crazy_muxes (
//Inputs
	//Format is {addr, wr_data, wr_en}
	.from_sn({snooper_wr_addr, snooper_wr_data, snooper_wr_en}),
	//Format is {addr, rd_en}
	.from_cpu({cpu_rd_addr, cpu_rd_en}),
	.from_fwd({fwd_rd_addr, fwd_rd_en}),
	//Format is {rd_data}
	.from_ping(ping_do),
	.from_pang(pang_do),
	.from_pung(pung_do),
	
	//Outputs
	//Format is {rd_data}
	.to_cpu(membuf_rd_data),
	.to_fwd(forwarder_rd_data),
	//Format here is {addr, wr_data, wr_en, rd_en}
	.to_ping({ping_addr, ping_di, ping_wr_en, ping_rd_en}),
	.to_pang({pang_addr, pang_di, pang_wr_en, pang_rd_en}),
	.to_pung({pung_addr, pung_di, pung_wr_en, pung_rd_en}),
	
	//Selects
	.sn_sel(sn_sel),
	.cpu_sel(cpu_sel),
	.fwd_sel(fwd_sel)
);

//Instantiate memories
packet_ram # (
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(`DATA_WIDTH)
) ping (
	.clk(clk),
	.addra(ping_addr),
	.dia(ping_di),
	.wr_en(ping_wr_en),
	.rd_en(ping_rd_en), //read enable
	.doa(ping_do)
);

packet_ram # (
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(`DATA_WIDTH)
) pang (
	.clk(clk),
	.addra(pang_addr),
	.dia(pang_di),
	.wr_en(pang_wr_en),
	.rd_en(pang_rd_en), //read enable
	.doa(pang_do)
);

packet_ram # (
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(`DATA_WIDTH)
) pung (
	.clk(clk),
	.addra(pung_addr),
	.dia(pung_di),
	.wr_en(pung_wr_en),
	.rd_en(pung_rd_en), //read enable
	.doa(pung_do)
);

endmodule

