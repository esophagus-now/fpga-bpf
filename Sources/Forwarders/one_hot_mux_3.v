`timescale 1ns / 1ps
/*
one_hot_mux_3.v

A special MUX which uses one-hot select signals instead of an "encoded" binary
value. It is specially coded to map into a single 6-LUT. This is based on the 
FPGA I am currently using (an ultrascale+); it would probably be necessary to
tailor-make this to fit the FPGA architecture you're using.

It would be tricky, but I think I could make the width a parameter somehow.

Anyway, an important property here is that Q is guaranteed to be zero when nothing
is selected. That lets you use an OR-reduction tree to combine the output of
several of these multiplexers (instead of needing multiplexers). Again: I'm
being aggressive about keeping combo paths short.
*/


module one_hot_mux_3(
	input wire data_A,
	input wire en_A,
	input wire data_B,
	input wire en_B,
	input wire data_C,
	input wire en_C,
	
	output wire Q
);

	assign Q = 
		(data_A && en_A) ||
		(data_B && en_B) ||
		(data_C && en_C);

endmodule
