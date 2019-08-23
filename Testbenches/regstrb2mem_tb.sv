`timescale 1ns / 1ps
/*
regstrb2mem_tb.sv

Simple testbench for regstrb2mem.v
*/


module regstrb2mem_tb();
reg clk;

//Interface to codemem
wire [9:0] code_mem_wr_addr;
wire [63:0] code_mem_wr_data;
wire code_mem_wr_en;

//Interface from regs
reg [31:0] inst_high_value;
reg inst_high_strobe;
reg [31:0] inst_low_value;
reg inst_low_strobe;
reg control_start;

integer fd;

initial begin
	clk <= 0;
	inst_high_value <= 0;
	inst_high_strobe <= 0;
	inst_low_value <= 0;
	inst_low_strobe <= 0;
	control_start <= 0;
	
	fd = $fopen("regstr2mem_drivers.mem", "r");
	while($fgetc(fd) != "\n") begin end; //Skip first line (which contains comments)
	
end

always #5 clk <= ~clk;

always @(posedge clk) begin
	$fscanf(fd, "%h%b%h%b%b", inst_high_value, inst_high_strobe, inst_low_value, inst_low_strobe, control_start);
	if ($feof(fd)) #20 $finish;
end

regstrb2mem DUT (
	.clk(clk),

	//Interface to codemem
	.code_mem_wr_addr(code_mem_wr_addr),
	.code_mem_wr_data(code_mem_wr_data),
	.code_mem_wr_en(code_mem_wr_en),
	
	//Interface from regs
	.inst_high_value(inst_high_value),
	.inst_high_strobe(inst_high_strobe),
	.inst_low_value(inst_low_value),
	.inst_low_strobe(inst_low_strobe),
	
	.control_start(control_start)
);

endmodule
