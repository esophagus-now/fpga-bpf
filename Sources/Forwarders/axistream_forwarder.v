`timescale 1ns / 1ps
/*
axistream_forwarder.v
A simple forwarder which reads a packet out from packetmem.v and send it along
using the AXI Stream protocol. I don't make any claims that it satisfies every
last stipulation in the official AXI Stream spec.
*/


//God what a mess... need to fix the packet length soon!
`define PLEN_WIDTH (ADDR_WIDTH+1)

module axistream_forwarder # (parameter
	DATA_WIDTH = 64,
	ADDR_WIDTH = 9,
	PESSIMISTIC = 0
)(
	
	input wire clk,
	
	//AXI Stream interface
	output wire [DATA_WIDTH-1:0] TDATA, //Registered in another module
	output reg TVALID = 0,
	output reg TLAST = 0,
	input wire TREADY,	
	
	//Interface to packetmem
	output reg [ADDR_WIDTH-1:0] forwarder_rd_addr = 0,
	input wire [DATA_WIDTH-1:0] forwarder_rd_data,
	output wire forwarder_rd_en,
	output wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	input wire ready_for_forwarder,
	input wire [`PLEN_WIDTH-1:0] len_to_forwarder
);

wire ready_for_forwarder_internal;
wire [`PLEN_WIDTH-1:0] len_to_forwarder_internal;


reg [DATA_WIDTH-1:0] TDATA_r = 0;
always @(posedge clk) TDATA_r = TDATA;
reg TLAST_r = 0;
always @(posedge clk) TLAST_r = TLAST;
reg TREADY_r = 0;
always @(posedge clk) TREADY_r = TREADY;

wire still_hangin_on;
assign still_hangin_on = TLAST_r && !TREADY_r;

////////////////////////////////////////
////////// PESSIMISTIC MODE ////////////
////////////////////////////////////////
generate
if (PESSIMISTIC) begin
	//Did this to improve timing
	//Basically, rd_en was combinationally dependent on ready_for_forwarder, which
	//was making these long combinational paths.
	//There's also a hack here: since ready is delayed, we always need to wait an
	//extra cycle after we assert the done signal (for the ready register to "refill")
	//So, if done is 1, we can just force this value to be zero.
	reg ready_for_forwarder_r = 0;
	always @(posedge clk) ready_for_forwarder_r <= ready_for_forwarder && !forwarder_done;
	assign ready_for_forwarder_internal = ready_for_forwarder_r && !still_hangin_on;
	reg [`PLEN_WIDTH-1:0] len_to_forwarder_r;
	always @(posedge clk) len_to_forwarder_r <= len_to_forwarder;
	assign len_to_forwarder_internal = len_to_forwarder_r;
end
///////////////////////////////////////
////////// OPTIMISTIC MODE ////////////
///////////////////////////////////////
else begin
	assign ready_for_forwarder_internal = ready_for_forwarder && !still_hangin_on;
	assign len_to_forwarder_internal = len_to_forwarder;
end
endgenerate
////////////////////////////////////////

//Calculate max addr
wire [ADDR_WIDTH-1:0] maxaddr;
assign maxaddr = len_to_forwarder_internal[`PLEN_WIDTH-1 -: ADDR_WIDTH];

//This logic keeps getting messier as I discover more corner cases...
//Essentially, once we get to the end of the packet, we need to be
//able to hold the outputs constant until the slave is ready
assign TDATA = still_hangin_on ? TDATA_r : forwarder_rd_data; 

wire TLAST_next;
assign TLAST_next = (forwarder_rd_addr >= maxaddr && forwarder_rd_en) //The next flit in TDATA is the last, in this case 
					|| (TLAST && !TREADY); //This means TLAST has not been read yet


wire [ADDR_WIDTH-1:0] next_addr;
assign next_addr = (ready_for_forwarder_internal && forwarder_rd_en) ? ((forwarder_rd_addr >= maxaddr) ? 0 : forwarder_rd_addr+1) : forwarder_rd_addr;

//We need to enable a read under the following circumstances:
// TVALID	|	TREADY	|	ready_for_forwarder |	rd_en
//	0			0			0					|	0		//Can't read if not ready for forwarder
//	0			0			1					|	1		//We can read, and we have no saved value yet
//	0			1			0					|	0		//Can't read if not ready for forwarder
//	0			1			1					|	1		//We can read, and we have no saved value yet
//	1			0			0					|	0		//Can't read if not ready for forwarder
//	1			0			1					|	0		//We have a saved value which we can't overwrite
//	1			1			0					|	0		//Can't read if not ready for forwarder
//	1			1			1					|	1		//The saved value is beign consumed, and we can read
//Oh yeah, now that I write it out, that makes sense. We always need ready_for_forwarder
//before reading from memory. And we read if TVALID is low, or if (TREADY && TVALID) is high.
//However, if you do the boolean algebra, letting A = TREADY and B = TVALID,
// AB + B' = 
// (A + B')(B + B') = 	(Distribute OR over AND)
// A + B'
// This is equal to, ready_for_forwarder && (!TVALID || (TVALID && TREADY))
// Special case:
assign forwarder_rd_en = ready_for_forwarder_internal && (forwarder_rd_addr <= maxaddr) && (TREADY || !TVALID) && !TLAST;

wire TVALID_next;
//I should do another truth table:
// TVALID	|	TREADY	|	forwarder_rd_en		|	TVALID_next
//	0			0			0					|	0			//TVALID was 0, and no new memory was read
//	0			0			1					|	1			//New memory was read
//	0			1			0					|	0			//TVALID was 0, and no new memory was read
//	0			1			1					|	1			//TVALID was 0, but new memory was read
//	1			0			0					|	1			//TVALID was 1, and saved value was not emptied
//	1			0			1					|	d			//This can never happen due to the logic for forwarder_rd_en
//	1			1			0					|	0			//The saved value will be emptied, and no new value is read
//	1			1			1					|	1			//The saved value will be emptied and replaced
// KMAP:
//	{TREADY, TVALID}		00	01	11	10
//  forwarder_rd_en = 0		0	1	0	0
//  forwarder_rd_en = 1		1	1	1	d
// TVALID_next = forwarder_rd_en || (!TREADY && TVALID)
assign TVALID_next = forwarder_rd_en || (!TREADY && TVALID);

always @(posedge clk) begin
	forwarder_rd_addr <= next_addr;
	TVALID <= TVALID_next;
	TLAST <= TLAST_next;
end

assign forwarder_done = TLAST && TVALID && TREADY;
endmodule

`undef PLEN_WIDTH