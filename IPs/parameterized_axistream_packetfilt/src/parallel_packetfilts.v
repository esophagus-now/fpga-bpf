`timescale 1ns / 1ps
/*
parallel_packetfilts.v

Tricky Verilog file to automatically generate a parameterizable number of parallel
BPFVMs, complete with associated snoopsplits and fwdcombines. Copied below are the
original comments from packetfilt.v, which is eesentially the same thing as this 
design (except hardcoded for only a single BPFVM):

Intended to be a top-level module for a packaged IP. For now, it only grafts an AXI 
slave onto the interface for adding new instructions. In the future, it should also
include some way to add a parameterizable number of snoopers as well as manage their
configuration.
*/

//I didn't have great luck with localparams
`define PACKET_DATA_WIDTH (2**(3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH))
//God what a mess... need to fix the packet length soon!
`define PLEN_WIDTH (SNOOP_FWD_ADDR_WIDTH+1)


module parallel_packetfilts # (
    parameter CODE_ADDR_WIDTH = 10, // codemem depth = 2^CODE_ADDR_WIDTH
    parameter PACKET_BYTE_ADDR_WIDTH = 12, // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    parameter SNOOP_FWD_ADDR_WIDTH = 9,
    //this makes the data width of the snooper and fwd equal to:
    // 2^{3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH}
    parameter N = 5, //The number of parallel VMs,
	parameter PESSIMISTIC = 0
)(

    // Clock and Reset
    input  wire                      axi_aclk,
    input  wire                      rst,
                                     
    //Interface to snooper
    input wire [SNOOP_FWD_ADDR_WIDTH-1:0] snooper_wr_addr,
	input wire [`PACKET_DATA_WIDTH-1:0] snooper_wr_data, //Hardcoded to 64 bits. TODO: change this to a parameter?
	input wire snooper_wr_en,
	input wire snooper_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_snooper,
    
	//Interface to forwarder
	input wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data,
	input wire forwarder_rd_en,
	input wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_forwarder,
	output wire [`PLEN_WIDTH-1:0] len_to_forwarder,
	
	//Interface to codemem
	input wire [CODE_ADDR_WIDTH-1:0] code_mem_wr_addr,
	input wire [63:0] code_mem_wr_data, //Instructions are always 64 bits wide
	input wire code_mem_wr_en
);

//Arbiter works on 4 wires at a time. Pad to nearest multiple of 4
localparam padded_size = (N % 4 == 0) ? N : (N - (N%4) + 4);
//Forwarder has the added onus of multiplexing the data and len lines
localparam padded_size_for_muxing = (N % 3 == 0) ? N : (N - (N%3) + 3);
localparam num_forwarder_enables = (padded_size_for_muxing > padded_size) ? padded_size_for_muxing: padded_size;

//Wires for snoop arbiting
wire snooper_readies[0:padded_size-1];
wire snooper_enables[0:padded_size-1];
wire VM_snoop_enables[0:padded_size-1];
reg VM_snoop_enables_saved[0:padded_size-1];

//Wires for forwarder arbiting
wire forwarder_readies[0:padded_size-1];
wire forwarder_enables[0:num_forwarder_enables-1];
wire VM_forwarder_enables[0:num_forwarder_enables-1];
reg VM_forwarder_enables_saved[0:num_forwarder_enables-1];

wire [`PACKET_DATA_WIDTH-1:0] forwarder_datas [0:padded_size_for_muxing-1];
wire [`PLEN_WIDTH-1:0] forwarder_lens [0:padded_size_for_muxing-1];

genvar i;

for (i = 0; i < padded_size; i = i+1) begin
	initial VM_snoop_enables_saved[i] <= 0;
	always @(posedge axi_aclk) VM_snoop_enables_saved[i] <= VM_snoop_enables[i];
	
end

//Terrible situation: because forwarder has two jobs, we need sometimes to have more
//(dummy) enable signals
for (i = 0; i < num_forwarder_enables; i = i+1) begin
	initial VM_forwarder_enables_saved[i] <= 0;
	always @(posedge axi_aclk) VM_forwarder_enables_saved[i] <= VM_forwarder_enables[i];
end

reg do_snoop_select = 1;
reg do_forwarder_select = 1;
always @(posedge axi_aclk) begin
	do_snoop_select <= snooper_done || !ready_for_snooper;
	do_forwarder_select <= forwarder_done || !ready_for_forwarder;
end

for (i = 0; i < padded_size; i = i+1) begin
	assign VM_snoop_enables[i] =
		do_snoop_select ?
			snooper_enables[i]
			: VM_snoop_enables_saved[i]
	; 
	
end


for (i = 0; i < num_forwarder_enables; i = i+1) begin
	assign VM_forwarder_enables[i] =
		do_forwarder_select ?
			forwarder_enables[i]
			: VM_forwarder_enables_saved[i]
	; 
end

//This for loop instantiates all the VMs.
for (i = 0; i < N; i = i+1) begin : VMs
	bpfvm # (
    .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH), // codemem depth = 2^CODE_ADDR_WIDTH
    .PACKET_BYTE_ADDR_WIDTH(PACKET_BYTE_ADDR_WIDTH), // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    .SNOOP_FWD_ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH),
    .PESSIMISTIC(PESSIMISTIC)
	) the_VM (
		.rst(rst), //Reset should be high if resetn is LOW or if start is LOW 
		.clk(axi_aclk),
		//Interface to an external module which will fill codemem
		.code_mem_wr_addr(code_mem_wr_addr), 
		.code_mem_wr_data(code_mem_wr_data), 
		.code_mem_wr_en(code_mem_wr_en), 
		
		//Interface to snooper
		.snooper_wr_addr(snooper_wr_addr),
		.snooper_wr_data(snooper_wr_data), 
		.snooper_wr_en(snooper_wr_en && VM_snoop_enables[i]),
		.snooper_done(snooper_done && VM_snoop_enables[i]), 
		.ready_for_snooper(snooper_readies[i]),
		
		//Interface to forwarder
		.forwarder_rd_addr(forwarder_rd_addr), 
		.forwarder_rd_data(forwarder_datas[i]), 
		.forwarder_rd_en(forwarder_rd_en && VM_forwarder_enables[i]), 
		.forwarder_done(forwarder_done && VM_forwarder_enables[i]), 
		.ready_for_forwarder(forwarder_readies[i]), 
		.len_to_forwarder(forwarder_lens[i]) 
	);
end

//Fill rest of padding with zeroes
//I'm pretty sure Vivado can optimize all these away 
for (i = N; i < padded_size; i = i+1) begin
	assign snooper_readies[i] = 0;
	assign forwarder_readies[i] = 0;
end
for (i = N; i < padded_size_for_muxing; i = i+1) begin
	assign forwarder_datas[i] = 0;
	assign forwarder_lens[i] = 0;
end

localparam num_arbs = padded_size/4;
wire snoop_carries[0:num_arbs+1-1];
assign snoop_carries[0] = 0;
wire forwarder_carries[0:num_arbs+1-1];
assign forwarder_carries[0] = 0;

//This for loop instantiates all the snoop and forwarder arbiters
//TODO: Have a pessimized version which adds pipeline registers
//(essentially becomes like an AXI Stream register slice)
for (i = 0; i < num_arbs; i = i+1) begin: arbs
	arbiter_4 snoop_arb (
		.any_in(snoop_carries[i]),
		.mem_ready_A(snooper_readies[4*i+0]),
		.mem_ready_B(snooper_readies[4*i+1]),
		.mem_ready_C(snooper_readies[4*i+2]),
		.mem_ready_D(snooper_readies[4*i+3]),
		.en_A(snooper_enables[4*i+0]),
		.en_B(snooper_enables[4*i+1]),
		.en_C(snooper_enables[4*i+2]),
		.en_D(snooper_enables[4*i+3]),
		.any_out(snoop_carries[i+1])
	);
	arbiter_4 fwd_arb (
		.any_in(forwarder_carries[i]),
		.mem_ready_A(forwarder_readies[4*i+0]),
		.mem_ready_B(forwarder_readies[4*i+1]),
		.mem_ready_C(forwarder_readies[4*i+2]),
		.mem_ready_D(forwarder_readies[4*i+3]),
		.en_A(forwarder_enables[4*i+0]),
		.en_B(forwarder_enables[4*i+1]),
		.en_C(forwarder_enables[4*i+2]),
		.en_D(forwarder_enables[4*i+3]),
		.any_out(forwarder_carries[i+1])
	);
end

//This takes care of the case when we have a larger length padded for muxes
for (i = padded_size; i < num_forwarder_enables; i = i+1) begin
	assign forwarder_enables[i] = 0;
end 

assign ready_for_snooper = snoop_carries[num_arbs];
assign ready_for_forwarder = forwarder_carries[num_arbs];

//Last thing we need is the hideous logic for "mutiplexing" the read data and
//len_to_forwarder_lines using the one-hot enable signals from the arbiters. I
//took special care to keep the combinational path short.

localparam num_muxes = padded_size_for_muxing/3;

wire [0:num_muxes-1] muxed_data [`PACKET_DATA_WIDTH-1:0];
wire [0:num_muxes-1] muxed_lens [`PLEN_WIDTH-1:0];
wire [`PACKET_DATA_WIDTH-1:0] reduced_data; //We'll see how smartly Vivado synthesizes Verilog's OR reduction operator
wire [`PLEN_WIDTH-1:0] reduced_len;

for (i = 0; i < num_muxes; i = i+1) begin: muxes
	genvar j;
	for (j = 0; j < `PACKET_DATA_WIDTH; j = j+1) begin: datamuxes
		one_hot_mux_3 bitmux (
			.data_A(forwarder_datas[3*i+0][j]),
			.en_A(VM_forwarder_enables[3*i+0]), //TODO: rename this signal to something less confusing
			
			.data_B(forwarder_datas[3*i+1][j]),
			.en_B(VM_forwarder_enables[3*i+1]), //TODO: rename this signal to something less confusing
			
			.data_C(forwarder_datas[3*i+2][j]),
			.en_C(VM_forwarder_enables[3*i+2]), //TODO: rename this signal to something less confusing
			
			.Q(muxed_data[j][i])
		);
	end
	for (j = 0; j < `PLEN_WIDTH; j = j+1) begin: lenmuxes
		one_hot_mux_3 bitmux (
			.data_A(forwarder_lens[3*i+0][j]),
			.en_A(VM_forwarder_enables[3*i+0]), //TODO: rename this signal to something less confusing
			
			.data_B(forwarder_lens[3*i+1][j]),
			.en_B(VM_forwarder_enables[3*i+1]), //TODO: rename this signal to something less confusing
			
			.data_C(forwarder_lens[3*i+2][j]),
			.en_C(VM_forwarder_enables[3*i+2]), //TODO: rename this signal to something less confusing
			
			.Q(muxed_lens[j][i])
		);
	end
end

for (i = 0; i < `PACKET_DATA_WIDTH; i = i+1) begin
	assign forwarder_rd_data[i] = |muxed_data[i]; //I hope this works out!
end
for (i = 0; i < `PLEN_WIDTH; i = i+1) begin
	assign len_to_forwarder[i] = |muxed_lens[i]; //I hope this works out!
end

endmodule
