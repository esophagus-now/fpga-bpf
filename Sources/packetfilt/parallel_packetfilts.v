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
    parameter N = 5 //The number of parallel VMs
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

localparam SNOOP_INTF_TOTAL_BITS = SNOOP_FWD_ADDR_WIDTH + `PACKET_DATA_WIDTH + 1 + 1 + 1;
wire [SNOOP_INTF_TOTAL_BITS-1:0] snoopsplit_tree [0:N + (N-1) -1];

localparam FWD_INTF_TOTAL_BITS = SNOOP_FWD_ADDR_WIDTH + `PACKET_DATA_WIDTH + `PLEN_WIDTH + 1 + 1 + 1;
wire [FWD_INTF_TOTAL_BITS-1:0] fwdcomb_tree [0:N + (N-1) -1];

genvar i;

//This for loop instantiates all the VMs.
for (i = 0; i < N; i = i+1) begin : VMs
	//I wish Verilog had VHDL's alias keyword...
	`define SNOOP_LOCAL snoopsplit_tree[i]
	`define FWD_LOCAL fwdcomb_tree[i]
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] snooper_wr_addr_local;
	wire [`PACKET_DATA_WIDTH-1:0] snooper_wr_data_local;
	wire snooper_wr_en_local;
	wire snooper_done_local;
	wire ready_for_snooper_local;
	
	//Does direction matter?
	//Turns out it doesn't, so in the future I may come back and make this all consistent
	assign snooper_wr_addr_local = `SNOOP_LOCAL[SNOOP_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH];
	assign snooper_wr_data_local = `SNOOP_LOCAL[SNOOP_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
	assign snooper_wr_en_local = `SNOOP_LOCAL[2];
	assign snooper_done_local = `SNOOP_LOCAL[1];
	assign `SNOOP_LOCAL[0] = ready_for_snooper_local;
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr_local;
	wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data_local;
	wire [`PLEN_WIDTH-1:0] len_to_forwarder_local;
	wire forwarder_rd_en_local;
	wire forwarder_done_local; //NOTE: this must be a 1-cycle pulse.
	wire ready_for_forwarder_local;
	
	assign forwarder_rd_addr_local = `FWD_LOCAL[FWD_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH];
	assign forwarder_rd_data_local = `FWD_LOCAL[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
	assign len_to_forwarder_local = `FWD_LOCAL[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH];
	assign forwarder_rd_en_local = `FWD_LOCAL[2];
	assign forwarder_done_local = `FWD_LOCAL[1];
	assign `FWD_LOCAL[0] = ready_for_forwarder_local;
	
	bpfvm # (
    .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH), // codemem depth = 2^CODE_ADDR_WIDTH
    .PACKET_BYTE_ADDR_WIDTH(PACKET_BYTE_ADDR_WIDTH), // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    .SNOOP_FWD_ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH)
	) the_VM (
		.rst(rst), //Reset should be high if resetn is LOW or if start is LOW 
		.clk(axi_aclk),
		//Interface to an external module which will fill codemem
		.code_mem_wr_addr(code_mem_wr_addr), //TODO: figure this out
		.code_mem_wr_data(code_mem_wr_data), //TODO: figure this out
		.code_mem_wr_en(code_mem_wr_en), //TODO: figure this out
		
		//Interface to snooper
		.snooper_wr_addr(snooper_wr_addr_local),
		.snooper_wr_data(snooper_wr_data_local), //Hardcoded to 32 bits. TODO: change this to 64?
		.snooper_wr_en(snooper_wr_en_local),
		.snooper_done(snooper_done_local), //NOTE: this must be a 1-cycle pulse.
		.ready_for_snooper(ready_for_snooper_local),
		
		//Interface to forwarder
		.forwarder_rd_addr(forwarder_rd_addr_local), 
		.forwarder_rd_data(forwarder_rd_data_local), 
		.forwarder_rd_en(forwarder_rd_en_local), 
		.forwarder_done(forwarder_done_local), //NOTE: this must be a 1-cycle pulse.
		.ready_for_forwarder(ready_for_forwarder_local), 
		.len_to_forwarder(len_to_forwarder_local) 
	);
	`undef LOCAL
end


//This for loop instantiates all the snoopsplits in the tree.
for (i = 0; i < N-1; i = i+1) begin: splittree
	`define LOCAL snoopsplit_tree[N+i]
	`define LEFT snoopsplit_tree[2*i]
	`define RIGHT snoopsplit_tree[2*i + 1]
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] snooper_wr_addr_local;
	wire [`PACKET_DATA_WIDTH-1:0] snooper_wr_data_local;
	wire snooper_wr_en_local;
	wire snooper_done_local;
	wire ready_for_snooper_local;
	
	assign snooper_wr_addr_local = `LOCAL[SNOOP_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH];
	assign snooper_wr_data_local = `LOCAL[SNOOP_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
	assign snooper_wr_en_local = `LOCAL[2];
	assign snooper_done_local = `LOCAL[1];
	assign `LOCAL[0] = ready_for_snooper_local;
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] snooper_wr_addr_left;
	wire [`PACKET_DATA_WIDTH-1:0] snooper_wr_data_left;
	wire snooper_wr_en_left;
	wire snooper_done_left;
	wire ready_for_snooper_left;
	
	assign `LEFT[SNOOP_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH] = snooper_wr_addr_left;
	assign `LEFT[SNOOP_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH] = snooper_wr_data_left;
	assign `LEFT[2] = snooper_wr_en_left;
	assign `LEFT[1] = snooper_done_left;
	assign ready_for_snooper_left = `LEFT[0];

	wire [SNOOP_FWD_ADDR_WIDTH-1:0] snooper_wr_addr_right;
	wire [`PACKET_DATA_WIDTH-1:0] snooper_wr_data_right;
	wire snooper_wr_en_right;
	wire snooper_done_right;
	wire ready_for_snooper_right;
	
	assign `RIGHT[SNOOP_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH] = snooper_wr_addr_right;
	assign `RIGHT[SNOOP_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH] = snooper_wr_data_right;
	assign `RIGHT[2] = snooper_wr_en_right;
	assign `RIGHT[1] = snooper_done_right;
	assign ready_for_snooper_right = `RIGHT[0];

	snoopsplit # (
		.DATA_WIDTH(`PACKET_DATA_WIDTH),
		.ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH)
	) node (
		.clk(axi_aclk),
	
		.wr_addr(snooper_wr_addr_local),
		.wr_data(snooper_wr_data_local),
		.mem_ready(ready_for_snooper_local),
		.wr_en(snooper_wr_en_local),
		.done(snooper_done_local),
		
		.wr_addr_left(snooper_wr_addr_left),
		.wr_data_left(snooper_wr_data_left),
		.mem_ready_left(ready_for_snooper_left),
		.wr_en_left(snooper_wr_en_left),
		.done_left(snooper_done_left),
		.wr_addr_right(snooper_wr_addr_right),
		.wr_data_right(snooper_wr_data_right),
		.mem_ready_right(ready_for_snooper_right),
		.wr_en_right(snooper_wr_en_right),
		.done_right(snooper_done_right)
		
		//.choice(choice), //TODO: figure this out
	);
	`undef LOCAL
	`undef LEFT
	`undef RIGHT
end

//This hooks up the module's snooper interface input to the root of the splitter tree
`define SNOOPROOT snoopsplit_tree[N + (N-1) -1]
assign `SNOOPROOT[SNOOP_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH] = snooper_wr_addr;
assign `SNOOPROOT[SNOOP_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH] = snooper_wr_data;
assign `SNOOPROOT[2] = snooper_wr_en;
assign `SNOOPROOT[1] = snooper_done;
assign ready_for_snooper = `SNOOPROOT[0];
`undef SNOOPROOT

//This for loop instantiates all the fwdcombines in the tree.
for (i = 0; i < N-1; i = i+1) begin: fwdtree
	`define LOCAL fwdcomb_tree[N+i]
	`define LEFT fwdcomb_tree[2*i]
	`define RIGHT fwdcomb_tree[2*i + 1]
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr_local;
	wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data_local;
	wire [`PLEN_WIDTH-1:0] len_to_forwarder_local;
	wire forwarder_rd_en_local;
	wire forwarder_done_local; //NOTE: this must be a 1-cycle pulse.
	wire ready_for_forwarder_local;
	
	assign forwarder_rd_addr_local = `LOCAL[FWD_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH];
	assign forwarder_rd_data_local = `LOCAL[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
	assign len_to_forwarder_local = `LOCAL[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH];
	assign forwarder_rd_en_local = `LOCAL[2];
	assign forwarder_done_local = `LOCAL[1];
	assign `LOCAL[0] = ready_for_forwarder_local;
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr_left;
	wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data_left;
	wire [`PLEN_WIDTH-1:0] len_to_forwarder_left;
	wire forwarder_rd_en_left;
	wire forwarder_done_left; //NOTE: this must be a 1-cycle pulse.
	wire ready_for_forwarder_left;
	
	assign forwarder_rd_addr_left = `LEFT[FWD_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH];
	assign forwarder_rd_data_left = `LEFT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
	assign len_to_forwarder_left = `LEFT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH];
	assign forwarder_rd_en_left = `LEFT[2];
	assign forwarder_done_left = `LEFT[1];
	assign `LEFT[0] = ready_for_forwarder_local;
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr_right;
	wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data_right;
	wire [`PLEN_WIDTH-1:0] len_to_forwarder_right;
	wire forwarder_rd_en_right;
	wire forwarder_done_right; //NOTE: this must be a 1-cycle pulse.
	wire ready_for_forwarder_right;
	
	assign forwarder_rd_addr_right = `RIGHT[FWD_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH];
	assign forwarder_rd_data_right = `RIGHT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
	assign len_to_forwarder_right = `RIGHT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH];
	assign forwarder_rd_en_right = `RIGHT[2];
	assign forwarder_done_right = `RIGHT[1];
	assign `RIGHT[0] = ready_for_forwarder_local;

	fwdcombine # (
		.DATA_WIDTH(`PACKET_DATA_WIDTH),
		.ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH)
	) node (
		.clk(axi_aclk),
		
		.forwarder_rd_addr_left(forwarder_rd_addr_left),
		.forwarder_rd_data_left(forwarder_rd_data_left),
		.forwarder_rd_en_left(forwarder_rd_en_left),
		.forwarder_done_left(forwarder_done_left), //NOTE: this must be a 1-cycle pulse.
		.ready_for_forwarder_left(ready_for_forwarder_left),
		.len_to_forwarder_left(len_to_forwarder_left),
		.forwarder_rd_addr_right(forwarder_rd_addr_right),
		.forwarder_rd_data_right(forwarder_rd_data_right),
		.forwarder_rd_en_right(forwarder_rd_en_right),
		.forwarder_done_right(forwarder_done_right), //NOTE: this must be a 1-cycle pulse.
		.ready_for_forwarder_right(ready_for_forwarder_right),
		.len_to_forwarder_right(len_to_forwarder_right),
		
		.forwarder_rd_addr(forwarder_rd_addr_local),
		.forwarder_rd_data(forwarder_rd_data_local),
		.forwarder_rd_en(forwarder_rd_en_local),
		.forwarder_done(forwarder_done_local), //NOTE: this must be a 1-cycle pulse.
		.ready_for_forwarder(ready_for_forwarder_local),
		.len_to_forwarder(len_to_forwarder_local)
	);
	
	`undef LOCAL
	`undef LEFT
	`undef RIGHT
end

//This hooks up the module's forwarder interface input to the root of the forwarder tree
`define FWDROOT fwdcomb_tree[N + (N-1) -1]
assign forwarder_rd_addr = `FWDROOT[FWD_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH];
assign forwarder_rd_data = `FWDROOT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
assign len_to_forwarder = `FWDROOT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH];
assign forwarder_rd_en = `FWDROOT[2];
assign forwarder_done = `FWDROOT[1];
assign `FWDROOT[0] = ready_for_forwarder;
`undef FWDROOT

endmodule
