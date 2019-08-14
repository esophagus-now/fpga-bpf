`timescale 1ns / 1ps
/*
axistream_forwarder.v

A simple forwarder which reads a packet out from packetmem.v and send it along
using the AXI Stream protocol. I don't make any claims that it satisfies every
last stipulation in the official AXI Stream spec.
*/


module axistream_forwarder # (parameter
	ADDR_WIDTH = 10
)(
	
	input wire clk,
	
	//AXI Stream interface
	output wire [63:0] TDATA,
	output reg TVALID = 0,
	output wire TLAST,
	input wire TREADY,	
	
	//Interface to packetmem
	output reg [ADDR_WIDTH-1:0] forwarder_rd_addr = 0,
	input wire [63:0] forwarder_rd_data,
	output wire forwarder_rd_en,
	output wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	input wire ready_for_forwarder,
	input wire [31:0] len_to_forwarder
);

assign TDATA = forwarder_rd_data;
assign TLAST = (forwarder_rd_addr == len_to_forwarder - 1);

wire [ADDR_WIDTH-1:0] next_addr;
assign next_addr = (ready_for_forwarder && forwarder_rd_en) ? (TLAST ? 0 : forwarder_rd_addr+1) : forwarder_rd_addr;

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
assign forwarder_rd_en = (ready_for_forwarder && (TREADY || !TVALID));

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
end

assign forwarder_done = TLAST;

endmodule
