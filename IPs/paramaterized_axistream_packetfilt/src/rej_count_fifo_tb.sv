`timescale 1ns / 1ps
/*
rej_count_fifo_tb.sv

This is a simple file just to convince me that the reject counting FIFO appears
to be working. It's not a complete test; that is in another file (which I haven't
made yet)
*/

`define COUNT_WIDTH 8
`define SHORT_DELAY repeat(5) @(posedge clk)
`define LONG_DELAY repeat(10) @(posedge clk)
`define SYNC @(posedge clk)

module rej_count_fifo_tb();
reg clk;
reg rst;

reg [`COUNT_WIDTH-1:0] rej_count_in;
reg shift_in;
reg countdown;
	
wire [`COUNT_WIDTH-1:0] head;
wire head_valid;

initial begin
	clk <= 0;
	rst <= 0;
	
	rej_count_in <= 0;
	shift_in <= 0;
	countdown <= 0;
end

always #5 clk <= ~clk;

initial begin
	`SHORT_DELAY;
	rej_count_in <= 8'd5;
	shift_in <= 1;
	`SYNC;
	rej_count_in <= 0;
	shift_in <= 0;
	
	`SHORT_DELAY;
	rej_count_in <= 8'd3;
	shift_in <= 1;
	`SYNC;
	rej_count_in <= 0;
	shift_in <= 0;
	
	
	`SHORT_DELAY;
	countdown <= 1;
	`SHORT_DELAY;
	rej_count_in <= 8'd3;
	shift_in <= 1;
	`SYNC;
	shift_in <= 0;
	
	`LONG_DELAY;
	
	$finish;
end

rej_count_fifo # (
	.COUNT_WIDTH(`COUNT_WIDTH)
) DUT (
	.clk(clk),
	.rst(rst),

	.rej_count_in(rej_count_in),
	.shift_in(shift_in),
	.countdown(countdown),
	
	.head(head),
	.head_valid(head_valid)
);

endmodule
