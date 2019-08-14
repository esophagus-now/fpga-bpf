`timescale 1ns / 1ps
/*
dataval_snooper_tb.sv

Tests the simple "data + valid" snooper using my newly discovered "fscanf" approach to testbenches.
*/


module dataval_snooper_tb();

reg clk;
integer fdin;

//wires/regs to snooper
reg [31:0] data;
reg strobe;

//Interface to packet mem
wire [9:0] wr_addr;
wire [31:0] wr_data;
reg mem_ready;
wire wr_en;
wire done;

initial begin
	clk <= 0;
	data <= 0;
	strobe <= 0;
	mem_ready <= 1;
	fdin = $fopen("dataval_snooper_drivers.mem", "r");
	while($fgetc(fdin) != "\n") begin
	end
end

always #5 clk <= ~clk;

always @(posedge clk) begin
	$fscanf(fdin, "%h%b", data, strobe); 
	if ($feof(fdin)) $finish;
end

dataval_snooper DUT (
	.clk(clk),
	.data(data),
	.strobe(strobe),
	
	//Interface to packet mem
	.wr_addr(wr_addr),
	.wr_data(wr_data),
	.mem_ready(mem_ready),
	.wr_en(wr_en),
	.done(done)
);


endmodule
