`timescale 1ns / 1ps

/*
axistream_packetfilt_tb.sv

This file runs a testbench for a block diagram which is not included in this repo. I would
include it, but I don't really know how at the moment. I'll figure that out eventually...

For the sake of completeness, here is a brief description of the diagram:

The centerpiece is the axistream_packetfilt. Its "snoop interface" is supplied by fakedata.v,
and its AXILite interface is supplied by an AXI VIP in master mode. That's pretty much it,
actually. The only other details are that I used a constant 1 for TREADY, and I needed a NOT
gate to wire up an active low reset into the packetfilt (which uses active high reset).
*/

import axi_vip_pkg::*;
import test_regmap_axi_vip_0_0_pkg::*;

`include "/home/mahkoe/research/bpfvm/fpga-bpf/Sources/bpf_defs.vh"

//This was the easiest way to do it:
parameter [63:0] inst0 = ({8'h0, `BPF_ABS, `BPF_H, `BPF_LD, 8'h88, 8'h88, 32'd12}); //ldh [12]                         
parameter [63:0] inst1 = ({8'b0, 1'b0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd13, 32'h800}); //jeq #0x800 jt 2 jf 15    
parameter [63:0] inst2 = ({8'h0, `BPF_ABS, `BPF_B, `BPF_LD, 8'h88, 8'h88, 32'd23}); //ldb [23]                         
parameter [63:0] inst3 = ({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd11, 32'h0006}); //jeq #0x6 jt 4 jf 15     
parameter [63:0] inst4 = ({8'h0, `BPF_ABS, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd20}); //ldh [20]                           
parameter [63:0] inst5 = ({8'h0, `BPF_JSET, `BPF_COMP_IMM, `BPF_JMP, 8'd9, 8'd0, 32'h1FFF}); //jset 0x1FFF jt 15 jf 6  
parameter [63:0] inst6 = ({8'h0, `BPF_MSH, `BPF_B, `BPF_LDX, 8'h0, 8'h0, 32'd14}); //ldxb_msh addr 14                  
parameter [63:0] inst7 = ({8'h0, `BPF_IND, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd14}); //ldh ind x+14                       
parameter [63:0] inst8 = ({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd2, 32'h0064}); //jeq 0x64 jt 9 jf 11      
parameter [63:0] inst9 = ({8'h0, `BPF_IND, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd16}); //ldh ind x+16                       
parameter [63:0] inst10 = ({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd3, 8'd4, 32'h00C8}); //jeq 0xC8 jt 14 jf 15    
parameter [63:0] inst11 = ({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd3, 32'h00C8}); //jeq 0xC8 jt 12 jf 15    
parameter [63:0] inst12 = ({8'h0, `BPF_IND, `BPF_H, `BPF_LD, 8'h0, 8'h0, 32'd16}); //ldh ind x+16                      
parameter [63:0] inst13 = ({8'h0, `BPF_JEQ, `BPF_COMP_IMM, `BPF_JMP, 8'd0, 8'd1, 32'h0064}); //jeq 0x64 jt 14 jf 15    
parameter [63:0] inst14 = ({8'h0, 3'b0, `RET_IMM,   `BPF_RET, 8'd0, 8'd0, 32'd65535}); //ret #65535                    
parameter [63:0] inst15 = ({8'h0, 3'b0, `RET_IMM,   `BPF_RET, 8'd0, 8'd0, 32'd0}); //ret #0  


module axistream_packetfilt_tb();

reg clk;
reg resetn;
wire [63:0]fwd_TDATA_0;
wire fwd_TLAST_0;
wire fwd_TVALID_0;

//Funny data types for axi vip
xil_axi_resp_t dummy;
xil_axi_prot_t noprot = 0;
test_regmap_axi_vip_0_0_mst_t agent;

initial begin
	clk <= 0;
	resetn <= 0;
	
	#200
	resetn <= 1;
    agent = new("master vip agent", DUT.test_regmap_i.axi_vip_0.inst.IF);
    agent.set_agent_tag("master_agent_0");
    agent.start_master();
    
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst0[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst0[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst1[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst1[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst2[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst2[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst3[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst3[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst4[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst4[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst5[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst5[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst6[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst6[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst7[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst7[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst8[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst8[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst9[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst9[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst10[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst10[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst11[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst11[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst12[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst12[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst13[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst13[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst14[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst14[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h0C, noprot, inst15[63:32], dummy);
	agent.AXI4LITE_WRITE_BURST('h08, noprot, inst15[31:0], dummy);
	agent.AXI4LITE_WRITE_BURST('h04, noprot, 32'd1, dummy); //Start the module
	
	@(posedge fwd_TLAST_0);
	
	#20 
	$finish;
end

always #5 clk <= ~clk;

test_regmap_wrapper DUT (
	.clk(clk),
	.resetn(resetn),
	.fwd_TDATA_0(fwd_TDATA_0),
	.fwd_TLAST_0(fwd_TLAST_0),
	.fwd_TVALID_0(fwd_TVALID_0)
);

endmodule
