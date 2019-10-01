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


//Fiddly logic for snoop arbiting
localparam padded_size = (N % 4 == 0) ? N : (N - (N%4) + 4);
wire snooparb_readies[0:padded_size-1];
wire snooparb_enables[0:padded_size-1];
wire VM_enables[0:padded_size-1];
reg VM_enables_saved[0:padded_size-1];

genvar i;

for (i = 0; i < padded_size; i = i+1) begin
	//Initialize array to all zeroes
	initial VM_enables_saved[i] <= 0;
	always @(posedge axi_aclk) VM_enables_saved[i] <= VM_enables[i];
end

reg do_select = 1;
always @(posedge axi_aclk) begin
	do_select <= snooper_done || !ready_for_snooper;
end

for (i = 0; i < padded_size; i = i+1) begin
	assign VM_enables[i] =
		do_select ?
			snooparb_enables[i]
			: VM_enables_saved[i]
	; 
end

//Declare internal wires for forward combine tree

localparam FWD_INTF_TOTAL_BITS = SNOOP_FWD_ADDR_WIDTH + `PACKET_DATA_WIDTH + `PLEN_WIDTH + 1 + 1 + 1;
wire [FWD_INTF_TOTAL_BITS-1:0] fwdcomb_tree [0:N + (N-1) -1];


//This for loop instantiates all the VMs.
for (i = 0; i < N; i = i+1) begin : VMs
	//I wish Verilog had VHDL's alias keyword...
	`define FWD_LOCAL fwdcomb_tree[i]
	
	//Does direction matter?
	//The order ABSOLUTELY MATTERS!!!!!!!
	//I really wish Verilog would just be smart and realize which one is the driver,
	//even if it is on the RHS of the =...
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr_local;
	wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data_local;
	wire [`PLEN_WIDTH-1:0] len_to_forwarder_local;
	wire forwarder_rd_en_local;
	wire forwarder_done_local; //NOTE: this must be a 1-cycle pulse.
	wire ready_for_forwarder_local;
	
	assign forwarder_rd_addr_local = `FWD_LOCAL[FWD_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH];
	assign `FWD_LOCAL[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH] = forwarder_rd_data_local;
	assign `FWD_LOCAL[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH] = len_to_forwarder_local;
	assign forwarder_rd_en_local = `FWD_LOCAL[2];
	assign forwarder_done_local = `FWD_LOCAL[1];
	assign `FWD_LOCAL[0] = ready_for_forwarder_local;
	
	bpfvm # (
    .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH), // codemem depth = 2^CODE_ADDR_WIDTH
    .PACKET_BYTE_ADDR_WIDTH(PACKET_BYTE_ADDR_WIDTH), // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    .SNOOP_FWD_ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH),
    .PESSIMISTIC(PESSIMISTIC)
	) the_VM (
		.rst(rst), //Reset should be high if resetn is LOW or if start is LOW 
		.clk(axi_aclk),
		//Interface to an external module which will fill codemem
		.code_mem_wr_addr(code_mem_wr_addr), //TODO: figure this out
		.code_mem_wr_data(code_mem_wr_data), //TODO: figure this out
		.code_mem_wr_en(code_mem_wr_en), //TODO: figure this out
		
		//Interface to snooper
		.snooper_wr_addr(snooper_wr_addr),
		.snooper_wr_data(snooper_wr_data), //Hardcoded to 32 bits. TODO: change this to 64?
		.snooper_wr_en(snooper_wr_en && VM_enables[i]),
		.snooper_done(snooper_done && VM_enables[i]), //NOTE: this must be a 1-cycle pulse.
		.ready_for_snooper(snooparb_readies[i]),
		
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


localparam num_arbs = padded_size/4;
wire snoop_carries[0:num_arbs+1-1];
assign snoop_carries[0] = 0;
//This for loop instantiates all the snoop arbiters
//TODO: Have a pessimized version which adds pipeline registers
//(essentially becomes like an AXI Stream register slice)
for (i = 0; i < num_arbs; i = i+1) begin: snooparbs
	snoop_arbiter_5 arb5 (
		.any_in(snoop_carries[i]),
		.mem_ready_A(snooparb_readies[4*i+0]),
		.mem_ready_B(snooparb_readies[4*i+1]),
		.mem_ready_C(snooparb_readies[4*i+2]),
		.mem_ready_D(snooparb_readies[4*i+3]),
		.en_A(snooparb_enables[4*i+0]),
		.en_B(snooparb_enables[4*i+1]),
		.en_C(snooparb_enables[4*i+2]),
		.en_D(snooparb_enables[4*i+3]),
		.any_out(snoop_carries[i+1])
	);
end

assign ready_for_snooper = snoop_carries[num_arbs];

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
	assign `LOCAL[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH] = forwarder_rd_data_local;
	assign `LOCAL[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH] = len_to_forwarder_local;
	assign forwarder_rd_en_local = `LOCAL[2];
	assign forwarder_done_local = `LOCAL[1];
	assign `LOCAL[0] = ready_for_forwarder_local;
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr_left;
	wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data_left;
	wire [`PLEN_WIDTH-1:0] len_to_forwarder_left;
	wire forwarder_rd_en_left;
	wire forwarder_done_left; //NOTE: this must be a 1-cycle pulse.
	wire ready_for_forwarder_left;
	
	assign `LEFT[FWD_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH] = forwarder_rd_addr_left;
	assign forwarder_rd_data_left = `LEFT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
	assign len_to_forwarder_left = `LEFT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH];
	assign `LEFT[2] = forwarder_rd_en_left;
	assign `LEFT[1] = forwarder_done_left;
	assign ready_for_forwarder_left = `LEFT[0];
	
	wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr_right;
	wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data_right;
	wire [`PLEN_WIDTH-1:0] len_to_forwarder_right;
	wire forwarder_rd_en_right;
	wire forwarder_done_right; //NOTE: this must be a 1-cycle pulse.
	wire ready_for_forwarder_right;
	
	assign `RIGHT[FWD_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH] = forwarder_rd_addr_right;
	assign forwarder_rd_data_right = `RIGHT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
	assign len_to_forwarder_right = `RIGHT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH];
	assign `RIGHT[2] = forwarder_rd_en_right;
	assign `RIGHT[1] = forwarder_done_right;
	assign ready_for_forwarder_right = `RIGHT[0];

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
assign `FWDROOT[FWD_INTF_TOTAL_BITS-1 -: SNOOP_FWD_ADDR_WIDTH] = forwarder_rd_addr;
assign forwarder_rd_data = `FWDROOT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH -: `PACKET_DATA_WIDTH];
//assign forwarder_rd_data = 'hDEB06;
assign len_to_forwarder = `FWDROOT[FWD_INTF_TOTAL_BITS-1 - SNOOP_FWD_ADDR_WIDTH - `PACKET_DATA_WIDTH -: `PLEN_WIDTH];
assign `FWDROOT[2] = forwarder_rd_en;
assign `FWDROOT[1] = forwarder_done;
assign ready_for_forwarder = `FWDROOT[0];
`undef FWDROOT

endmodule
