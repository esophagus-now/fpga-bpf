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
`define PACKLEN_WIDTH 32

module packetmem#(parameter
    ADDR_WIDTH = 10 
)(
	input wire clk,
	input wire p3ctrl_rst,
	
	//Interface to snooper
	input wire [ADDR_WIDTH-1:0] snooper_wr_addr,
	input wire [31:0] snooper_wr_data, //Hardcoded to 32 bits. TODO: should this get changed to 64?
	input wire snooper_wr_en,
	input wire snooper_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_snooper,
	
	//Interface to CPU
	input wire [ADDR_WIDTH+2-1:0] cpu_byte_rd_addr,
	input wire [1:0] transfer_sz,
	output wire [31:0] cpu_rd_data, //Hardcoded to 32 bits
	input wire cpu_rd_en,
	input wire cpu_rej,
	input wire cpu_acc, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_cpu,
	output wire [31:0] len_to_cpu,
	
	//Interface to forwarder
	input wire [ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [63:0] forwarder_rd_data,
	input wire forwarder_rd_en,
	input wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_forwarder,
	output wire [31:0] len_to_forwarder
);

//Forward declare wires for memories
wire [ADDR_WIDTH-1:0] ping_addr;
wire [2*`DATA_WIDTH-1:0] ping_do;
wire [`DATA_WIDTH-1:0] ping_di;
wire ping_wr_en;
wire ping_rd_en;
wire [`PACKLEN_WIDTH-1:0] ping_len;

wire [ADDR_WIDTH-1:0] pang_addr;
wire [2*`DATA_WIDTH-1:0] pang_do;
wire [`DATA_WIDTH-1:0] pang_di;
wire pang_wr_en;
wire pang_rd_en;
wire [`PACKLEN_WIDTH-1:0] pang_len;

wire [ADDR_WIDTH-1:0] pung_addr;
wire [2*`DATA_WIDTH-1:0] pung_do;
wire [`DATA_WIDTH-1:0] pung_di;
wire pung_wr_en;
wire pung_rd_en;
wire [`PACKLEN_WIDTH-1:0] pung_len;

//Declare wires for controller stuff
wire [1:0] sn_sel, cpu_sel, fwd_sel;

//Instantiate the controller
p3_ctrl dispatcher (
	.clk(clk),
	.rst(p3ctrl_rst),
	.A_done(snooper_done),
	.B_acc(cpu_acc), //Special case for me: B can "accept" a memory buffer and send it to C
	.B_rej(cpu_rej), //or it can "reject" it and send it back to A
	.C_done(forwarder_done),
	.sn_sel(sn_sel),
	.cpu_sel(cpu_sel),
	.fwd_sel(fwd_sel)
);

//Generate ready lines for the three agents
assign ready_for_snooper = sn_sel != 0;
assign ready_for_cpu = cpu_sel != 0;
assign ready_for_forwarder = fwd_sel != 0;

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


wire [1:0] ping_sel, pang_sel, pung_sel;
//Instantiate the crazy MUXes
painfulmuxes # (
	.ADDR_WIDTH(ADDR_WIDTH)
) crazy_muxes (
//Inputs
	//Format is {addr, wr_data, wr_en}
	.from_sn({snooper_wr_addr, snooper_wr_data, snooper_wr_en}),
	//Format is {addr, rd_en}
	.from_cpu({cpu_rd_addr, cpu_rd_en}),
	.from_fwd({forwarder_rd_addr[ADDR_WIDTH-2:0], 1'b0, forwarder_rd_en}), //This essentially multiplies the forwarder's read address by 2
	//Format is {rd_data, packet_len}
	.from_ping({ping_do, ping_len}),
	.from_pang({pang_do, pang_len}),
	.from_pung({pung_do, pung_len}),
	
	//Outputs
	//Format is {rd_data, packet_len}
	.to_cpu({membuf_rd_data, len_to_cpu}),
	.to_fwd({forwarder_rd_data, len_to_forwarder}),
	//Format here is {addr, wr_data, wr_en, rd_en}
	.to_ping({ping_addr, ping_di, ping_wr_en, ping_rd_en}),
	.to_pang({pang_addr, pang_di, pang_wr_en, pang_rd_en}),
	.to_pung({pung_addr, pung_di, pung_wr_en, pung_rd_en}),
	
	//Selects
	.sn_sel(sn_sel),
	.cpu_sel(cpu_sel),
	.fwd_sel(fwd_sel),
	.ping_sel(ping_sel),
	.pang_sel(pang_sel),
	.pung_sel(pung_sel)
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
	.doa(ping_do),
	.len_rst((ping_sel == 2'b10 && B_rej) || (ping_sel == 2'b11 && C_done)),
	.len(ping_len)
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
	.doa(pang_do),
	.len_rst((pang_sel == 2'b10 && B_rej) || (pang_sel == 2'b11 && C_done)),
	.len(pang_len)
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
	.doa(pung_do),
	.len_rst((pung_sel == 2'b10 && B_rej) || (pung_sel == 2'b11 && C_done)),
	.len(pung_len)
);

endmodule

