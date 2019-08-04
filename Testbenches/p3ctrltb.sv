`timescale 1ns / 1ps
/*
p3ctrltb.sv

As you can guess, this is a testbench file for p3ctrl.v
*/


module p3ctrltb();

reg clk;
reg A_done;
reg B_acc; //Special case for me: B can "accept" a memory buffer and send it to C
reg B_rej; //or it can "reject" it and send it back to A
reg C_done;

wire [1:0] sn_sel;
wire [1:0] cpu_sel;
wire [1:0] fwd_sel;
/*
wire [1:0] ping_sel;
wire [1:0] pang_sel;
wire [1:0] pung_sel;
//This logic was moved out of p3ctrl and into packetmem
*/
initial begin
	clk <= 0;
	A_done <= 0;
	B_acc <= 0;
	B_rej <= 0;
	C_done <= 0;
	
	//Snooper finishes loading something to ping
	repeat (2) @(negedge clk);
	A_done <= 1;
	@(negedge clk);
	A_done <= 0;
	
	//CPU rejects the packet
	repeat (2) @(negedge clk);
	B_rej <= 1;
	@(negedge clk);
	B_rej <= 0;
	
	//Snooper finishes loading something to pang
	repeat (2) @(negedge clk);
	A_done <= 1;
	@(negedge clk);
	A_done <= 0;
	
	//Snooper finishes loading something to pung
	//At same time, CPU accepts contents of pang
	repeat (2) @(negedge clk);
	A_done <= 1;
	B_acc <= 1;
	@(negedge clk);
	A_done <= 0;
	B_acc <= 0;
	
	//Snooper finishes loading something to ping
	repeat (2) @(negedge clk);
	A_done <= 1;
	@(negedge clk);
	A_done <= 0;
	
	//Forwarder finishes reading out pang
	repeat (2) @(negedge clk);
	C_done <= 1;
	@(negedge clk);
	C_done <= 0;
	
	repeat (2) @(negedge clk);
	$finish;
	
end

always #4 clk <= ~clk;

p3_ctrl DUT (
	.clk,
	.A_done,
	.B_acc, 
	.B_rej, 
	.C_done,
	
	.sn_sel,
	.cpu_sel,
	.fwd_sel//,
	//.ping_sel,
	//.pang_sel,
	//.pung_sel
	//This logic was moved into packetmem
);

endmodule
