`timescale 1ns / 1ps
/*
bpfvmtb.sv

A testbench for the bpfvm block diagram. Sadly, I don't know how to properly add
a block diagram into a repo. So, for the time being, I'll describe what it is:

Simply put, the bpfvm_datapath and bpfvm_ctrl are wired together in the obvious
way (i.e. connect matching signal names). Then, instantiate one packetmem and one
codemem, and connect the memory read inputs to the remaining outputs of the datapath
and controller. Finally, make all the memory write inputs (aswell as clock and rest)
external.
*/


module bpfvmtb();
reg clk;
reg [9:0]code_wr_addr;
reg [63:0]code_wr_data;
reg code_wr_en;
reg [31:0]pack_idata;
reg [9:0]pack_wr_addr;
reg pack_wr_en;
reg rst;

initial begin
	DUT.bpfvm_i.mycodemem.inst.myram.data[0] <= {16'h0000, 8'h0, 8'h0, 32'd10};
	DUT.bpfvm_i.mycodemem.inst.myram.data[1] <= {16'h0001, 8'h0, 8'h0, 32'd3};
	DUT.bpfvm_i.mycodemem.inst.myram.data[2] <= {16'h000C, 8'h0, 8'h0, 32'h0};
	DUT.bpfvm_i.mycodemem.inst.myram.data[3] <= {16'h0005, 8'h0, 8'h0, 32'hFFFFFFFE};
	clk <= 0;
	code_wr_addr <= 0;
	code_wr_data <= 0;
	code_wr_en <= 0;
	pack_idata <= 0;
	pack_wr_addr <= 0;
	pack_wr_en <= 0;
	rst <= 0;
	
	#200
	$finish;
end

always #4 clk <= ~clk;

bpfvm_wrapper DUT
   (clk,
    code_wr_addr,
    code_wr_data,
    code_wr_en,
    pack_idata,
    pack_wr_addr,
    pack_wr_en,
    rst);
endmodule