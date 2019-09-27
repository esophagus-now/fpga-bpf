`timescale 1ns / 1ps

/*

rej_count_fifo.v

This module is part of the technique for in-order forwarding and snooper splitters are used.
At some point, the project wiki should have a nice diagram showing the purpose of this module.

But to quickly try and explain: a BPFVM can have at most 3 accepted packets. Between acceptances,
there could be an unbounded number of rejects. We need to keep track of this.

Basically, every time the snooper finishes a packet, it enqueues the "index" of the BPFVM the
packet was sent to into a FIFO held by the forwarder. The forwarder checks the BPFVM pointed to
by the head of this FIFO; if the packet was rejected, it dequeues that entry without forwarding
the packet. Otherwise, it forwards the packet. If the decision has not been made yet, the 
forwarder must wait.

*/

//How to read this file:

//We begin by defining two submodules; a counter and a 2-to-4 decoder. There is
//nothing special about them whatsoever, besides the counter having an initial
//value of -1.

//Then, we define the module that we really want. Basically, I did my best to
//write it such that assignment to a signal happened before that signal was
//used elsewhere. Obviously this all happens concurrently, but I thought it
//would make it easier to read.
//But by far the best way to understand the rej_count_fifo module is to just look
//at the diagram on the project wiki.

//This is pretty much a bog-standard counter that I needed inside the main FIFO.
//The FIFO is made of counters, not registers, in order to support the technique described above.
module my_counter # (
	parameter WIDTH = 9
)(
	input wire clk,
	
	input wire load,
	input wire [WIDTH-1:0] D,
	input wire dec,
	
	output wire [WIDTH-1:0] Q,
	output wire carry
);

localparam [WIDTH-1:0] zeroes = 0;

reg [WIDTH-1:0] count = ~zeroes; //I hope this synthesizes...
wire [WIDTH-1:0] count_n = (load) ? D : ((dec) ? count-1 : count);
assign carry = (count == 0) && dec;

assign Q = count;
always @(posedge clk) begin
	count <= count_n;
end

endmodule

//A bog-standard 2-to-4 decoder
//It is combinataional; don't let the reg fool you!
module dec_2_to_4 (
	input wire [1:0] sel,
	output reg [3:0] dec
);

always @(*) begin
	case (sel)
		2'b00: dec = 4'b0001;
		2'b01: dec = 4'b0010;
		2'b10: dec = 4'b0100;
		2'b11: dec = 4'b1000; //This is techinically a don't care condition in my project
	endcase
end

endmodule

module rej_count_fifo # (
	parameter COUNT_WIDTH = 8
)(
	input wire clk,
	input wire rst,

	input wire [COUNT_WIDTH-1:0] rej_count_in,
	input wire shift_in,
	input wire countdown,
	
	output wire [COUNT_WIDTH-1:0] head,
	output wire head_valid
);

//Later we instantiate three counters. Think of them as being in a
//circular buffer, with read and write pointers
reg [1:0] rd_ptr = 0;
wire [1:0] rd_ptr_n;
reg [1:0] wr_ptr = 0;
wire [1:0] wr_ptr_n;

//Forward-declaring wires plugged into instantiated counters
wire [COUNT_WIDTH-1:0] count0, count1, count2;
wire inv_valid0, inv_valid1, inv_valid2;
wire carry0, carry1, carry2;

//Instantiate decoder on write pointer (I'm using the decoder like a "demux")
wire [3:0] wr_decoded;
dec_2_to_4 wr_ptr_decoder(.sel(wr_ptr), .dec(wr_decoded));
wire [3:0] rd_decoded;
dec_2_to_4 rd_ptr_decoder(.sel(rd_ptr), .dec(rd_decoded));

my_counter # (
	.WIDTH(COUNT_WIDTH+1)
) counter0 (
	.clk(clk),
	.load(shift_in && wr_decoded[0]),
	.D({1'b0, rej_count_in}),
	.dec(countdown && rd_decoded[0]),
	.Q({inv_valid0, count0}),
	.carry(carry0)
);

my_counter # (
	.WIDTH(COUNT_WIDTH+1)
) counter1 (
	.clk(clk),
	.load(shift_in && wr_decoded[1]),
	.D({1'b0, rej_count_in}),
	.dec(countdown && rd_decoded[1]),
	.Q({inv_valid1, count1}),
	.carry(carry1)
);

my_counter # (
	.WIDTH(COUNT_WIDTH+1)
) counter2 (
	.clk(clk),
	.load(shift_in && wr_decoded[2]),
	.D({1'b0, rej_count_in}),
	.dec(countdown && rd_decoded[2]),
	.Q({inv_valid2, count2}),
	.carry(carry2)
);

//Invert the top bit of the counter to get a valid bit
wire valid0, valid1, valid2;
assign valid0 = ~inv_valid0;
assign valid1 = ~inv_valid1;
assign valid2 = ~inv_valid2;


//Now, using the read pointer, select outputs from the right counter

//This lead to a nicer-looking output in Vivado
wire [COUNT_WIDTH+2 - 1:0] head_valid_carry;

assign head_valid_carry =
	(rd_ptr[1] == 1) ?
		{count2, valid2, carry2}
		:
		(rd_ptr[0] == 1) ?
			{count1, valid1, carry1}
			:
			{count0, valid0, carry0}
;

assign head = head_valid_carry[COUNT_WIDTH+2-1 -: COUNT_WIDTH];
assign head_valid = head_valid_carry[1];

wire head_carry;
assign head_carry = head_valid_carry[0];

assign rd_ptr_n = 
	(head_carry) ?
		(rd_ptr == 2'b10) ?
			2'b00
			:
			rd_ptr + 1
		:
		rd_ptr
;

assign wr_ptr_n = 
	(shift_in) ?
		(wr_ptr == 2'b10) ?
			2'b00
			:
			wr_ptr + 1
		:
		wr_ptr
;

always @(posedge clk) begin
	rd_ptr <= rd_ptr_n;
	wr_ptr <= wr_ptr_n;
end
endmodule
