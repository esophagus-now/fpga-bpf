`timescale 1ns / 1ps
/*

packetmem.v

This file is best described by a diagram available in the repo's wiki. It can
also be found under Figures/pingpangpung.png.

Essentially, instantiates three packetram modules. It also instantiates a bunch
of fiddly glue logic, including the p3ctrl module and the painfulmuxes module
in order to arbitrate everything.

One more thing: the CPU needs an extra "adapter". See, the CPU can ask for up
to 32 bits starting at any byte address. Our technique is to read two consecutive
words from the packet memory and select the parts we want to keep. The read_size_adapter
is what does this.

*/

//I had back luck with localparams
`define SNOOP_FWD_DATA_WIDTH (2**(3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH))
//Because of the support for unaligned reads, I actually use two ports of half the size
`define PORT_DATA_WIDTH (2**(2 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH))
`define PORT_ADDR_WIDTH (SNOOP_FWD_ADDR_WIDTH+1)
//God what a mess... need to fix the packet length soon!
`define PLEN_WIDTH (SNOOP_FWD_ADDR_WIDTH+1)

module packetmem#(
    parameter PACKET_BYTE_ADDR_WIDTH = 12, // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    parameter SNOOP_FWD_ADDR_WIDTH = 9
    //this makes the data width of the snooper and fwd equal to:
    // 2^{3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH}
)(
	input wire clk,
	input wire p3ctrl_rst,
	
	//Interface to snooper
	input wire [SNOOP_FWD_ADDR_WIDTH-1:0] snooper_wr_addr,
	input wire [`SNOOP_FWD_DATA_WIDTH-1:0] snooper_wr_data,
	input wire snooper_wr_en,
	input wire snooper_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_snooper,
	
	//Interface to CPU
	input wire [PACKET_BYTE_ADDR_WIDTH-1:0] cpu_byte_rd_addr,
	input wire [1:0] transfer_sz,
	output wire [31:0] cpu_rd_data, //Hardcoded to 32 bits
	input wire cpu_rd_en,
	input wire cpu_rej,
	input wire cpu_acc, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_cpu,
	output wire [`PLEN_WIDTH-1:0] len_to_cpu,
	
	//Interface to forwarder
	input wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [`SNOOP_FWD_DATA_WIDTH-1:0] forwarder_rd_data,
	input wire forwarder_rd_en,
	input wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_forwarder,
	output wire [`PLEN_WIDTH-1:0] len_to_forwarder
);

//TODO: I made a mistake, so the original names I gave to these constants no longer makes sense
//so I should fix them

//Forward declare wires for memories
wire [`PORT_ADDR_WIDTH-1:0] ping_addr;
wire [`SNOOP_FWD_DATA_WIDTH-1:0] ping_do;
wire [`SNOOP_FWD_DATA_WIDTH-1:0] ping_di;
wire ping_wr_en;
wire ping_rd_en;
wire [`PLEN_WIDTH-1:0] ping_len;

wire [`PORT_ADDR_WIDTH-1:0] pang_addr;
wire [`SNOOP_FWD_DATA_WIDTH-1:0] pang_do;
wire [`SNOOP_FWD_DATA_WIDTH-1:0] pang_di;
wire pang_wr_en;
wire pang_rd_en;
wire [`PLEN_WIDTH-1:0] pang_len;

wire [`PORT_ADDR_WIDTH-1:0] pung_addr;
wire [`SNOOP_FWD_DATA_WIDTH-1:0] pung_do;
wire [`SNOOP_FWD_DATA_WIDTH-1:0] pung_di;
wire pung_wr_en;
wire pung_rd_en;
wire [`PLEN_WIDTH-1:0] pung_len;

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

wire [`PORT_ADDR_WIDTH-1:0] adapted_cpu_rd_addr;
wire [2*`PORT_DATA_WIDTH-1:0] adapted_mem_rd_data;

read_size_adapter # (
	.PACKET_BYTE_ADDR_WIDTH(PACKET_BYTE_ADDR_WIDTH),
	.SNOOP_FWD_ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH)
) cpu_adapter (
	.clk(clk),
	.byte_rd_addr(cpu_byte_rd_addr),
	.transfer_sz(transfer_sz),
	.word_rd_addra(adapted_cpu_rd_addr),
	.bigword(adapted_mem_rd_data),
	.resized_mem_data(cpu_rd_data) //zero-padded on the left (when necessary)
);


wire [1:0] ping_sel, pang_sel, pung_sel;
//Instantiate the crazy MUXes
painfulmuxes # (
	.ADDR_WIDTH(`PORT_ADDR_WIDTH),
	.DATA_WIDTH(`SNOOP_FWD_DATA_WIDTH)
) crazy_muxes (
//Inputs
	//Format is {addr, wr_data, wr_en}
	.from_sn({snooper_wr_addr, 1'b0, snooper_wr_data, snooper_wr_en}), //The 1'b0 appends a zero to the end of the read address
	//Format is {addr, rd_en}
	.from_cpu({adapted_cpu_rd_addr, cpu_rd_en}),
	.from_fwd({forwarder_rd_addr, 1'b0, forwarder_rd_en}), //The 1'b0 appends a zero to the end of the read address
	//Format is {rd_data, packet_len}
	.from_ping({ping_do, ping_len}),
	.from_pang({pang_do, pang_len}),
	.from_pung({pung_do, pung_len}),
	
	//Outputs
	//Format is {rd_data, packet_len}
	.to_cpu({adapted_mem_rd_data, len_to_cpu}),
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
    .PORT_ADDR_WIDTH(`PORT_ADDR_WIDTH),
    .PORT_DATA_WIDTH(`PORT_DATA_WIDTH)
) ping (
	.clk(clk),
	.addra(ping_addr),
	.di(ping_di),
	.wr_en(ping_wr_en),
	.rd_en(ping_rd_en), //read enable
	.do(ping_do),
	.len_rst((ping_sel == 2'b10 && cpu_rej) || (ping_sel == 2'b11 && forwarder_done)), 
	.len(ping_len)
);

packet_ram # (
    .PORT_ADDR_WIDTH(`PORT_ADDR_WIDTH),
    .PORT_DATA_WIDTH(`PORT_DATA_WIDTH)
) pang (
	.clk(clk),
	.addra(pang_addr),
	.di(pang_di),
	.wr_en(pang_wr_en),
	.rd_en(pang_rd_en), //read enable
	.do(pang_do),
	.len_rst((pang_sel == 2'b10 && cpu_rej) || (pang_sel == 2'b11 && forwarder_done)),
	.len(pang_len)
);

packet_ram # (
    .PORT_ADDR_WIDTH(`PORT_ADDR_WIDTH),
    .PORT_DATA_WIDTH(`PORT_DATA_WIDTH)
) pung (
	.clk(clk),
	.addra(pung_addr),
	.di(pung_di),
	.wr_en(pung_wr_en),
	.rd_en(pung_rd_en), //read enable
	.do(pung_do),
	.len_rst((pung_sel == 2'b10 && cpu_rej) || (pung_sel == 2'b11 && forwarder_done)),
	.len(pung_len)
);

endmodule
`undef SNOOP_FWD_DATA_WIDTH
`undef PORT_DATA_WIDTH
`undef PORT_ADDR_WIDTH
