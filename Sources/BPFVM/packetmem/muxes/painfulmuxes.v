`timescale 1ns / 1ps
/*
painfulmuxes.v

This is the very tedious set of MUXes that connect the agents and buffers

I had been putting this off for too long...
but in the end it wasn't that hard

*/


//Each input wire on each agent/buffer needs a 3-mux

module mux3 # (parameter
	WIDTH = 1
)(
	input wire [WIDTH-1:0] A,
	input wire [WIDTH-1:0] B,
	input wire [WIDTH-1:0] C,
	input wire [1:0] sel,
	output wire [WIDTH-1:0] D
);

	assign D = (sel[1] == 1'b1) ? 	((sel[0] == 1'b1) ? C : B) :
									((sel[0] == 1'b1) ? A : 0);

endmodule

/*
Snooper:
--> 10 bit write addr
--> 32 bit write data (should I change this to 64 and use dual-port writing?)
--> 1 bit write enable

CPU (through read_size_adapter):
--> 10 bit read address
--> 1 bit read enable
<-- 64 bit read data

FWD (whose 9 bit read address is appended with a constant 0 bit):
--> 10 bit read address
--> 1 bit read enable
<-- 64 bit read data

Ping/Pang/Pung:
<-- 10 bit (dword-)address
<-- 32 bit write data (may be changed to 64 bits in the future)
<-- 1 bit read enable
<-- 1 bit write enable
--> 64 bit read data ( = {mem[addr],mem[addr+1]} )
*/

`define WRITE_WIDTH 64
`define READ_WIDTH 64
`define ENABLE_BIT 1
module painfulmuxes # (parameter
	ADDR_WIDTH = 10
)(
	//Inputs
	//Format is {addr, wr_data, wr_en}
	input wire [ADDR_WIDTH + `WRITE_WIDTH + `ENABLE_BIT -1:0] from_sn,
	//Format is {addr, rd_en}
	input wire [ADDR_WIDTH + `ENABLE_BIT -1:0] from_cpu,
	input wire [ADDR_WIDTH + `ENABLE_BIT -1:0] from_fwd,
	//Format is {rd_data, packet_len}
	input wire [`READ_WIDTH + ADDR_WIDTH -1:0] from_ping,
	input wire [`READ_WIDTH + ADDR_WIDTH -1:0] from_pang,
	input wire [`READ_WIDTH + ADDR_WIDTH -1:0] from_pung,
	
	//Outputs
	//Nothing to output to snooper, besides maybe a "ready" line
	//Format is {rd_data, packet_len}
	output wire [`READ_WIDTH + ADDR_WIDTH -1:0] to_cpu,
	output wire [`READ_WIDTH + ADDR_WIDTH -1:0] to_fwd,
	//Format here is {addr, wr_data, wr_en, rd_en}
	output wire [ADDR_WIDTH + `WRITE_WIDTH + 2*`ENABLE_BIT -1:0] to_ping,
	output wire [ADDR_WIDTH + `WRITE_WIDTH + 2*`ENABLE_BIT -1:0] to_pang,
	output wire [ADDR_WIDTH + `WRITE_WIDTH + 2*`ENABLE_BIT -1:0] to_pung,
	
	//Selects
	input wire [1:0] sn_sel,
	input wire [1:0] cpu_sel,
	input wire [1:0] fwd_sel,
	
	output wire [1:0] ping_sel,
	output wire [1:0] pang_sel,
	output wire [1:0] pung_sel
);

	//Compute the select lines for ping/pang/pung

muxselinvert muxthing(
	.sn_sel(sn_sel),
	.cpu_sel(cpu_sel),
	.fwd_sel(fwd_sel),
	.ping_sel(ping_sel),
	.pang_sel(pang_sel),
	.pung_sel(pung_sel)
);

mux3 # (`READ_WIDTH + ADDR_WIDTH) cpu_mux (
	.A(from_ping),
	.B(from_pang),
	.C(from_pung),
	.sel(cpu_sel),
	.D(to_cpu)
);

mux3 # (`READ_WIDTH + ADDR_WIDTH) fwd_mux (
	.A(from_ping),
	.B(from_pang),
	.C(from_pung),
	.sel(fwd_sel),
	.D(to_fwd)
);

//One agent always has exclusive control of a buffer, even though it
//doesn't use the read and write ports at the same time. Replace unused
//inputs/outputs with zeros

//Format here is {addr, wr_data, wr_en, rd_en}
wire [ADDR_WIDTH + `WRITE_WIDTH + 2*`ENABLE_BIT -1:0] from_sn_padded;
wire [ADDR_WIDTH + `WRITE_WIDTH + 2*`ENABLE_BIT -1:0] from_cpu_padded;
wire [ADDR_WIDTH + `WRITE_WIDTH + 2*`ENABLE_BIT -1:0] from_fwd_padded;

assign from_sn_padded = {from_sn, `ENABLE_BIT'b0};
assign from_cpu_padded = {from_cpu[ADDR_WIDTH + `ENABLE_BIT -1:1], `WRITE_WIDTH'b0, `ENABLE_BIT'b0, from_cpu[0]};
assign from_fwd_padded = {from_fwd[ADDR_WIDTH + `ENABLE_BIT -1:1], `WRITE_WIDTH'b0, `ENABLE_BIT'b0, from_fwd[0]};


mux3 # (ADDR_WIDTH + `WRITE_WIDTH + 2*`ENABLE_BIT) ping_mux (
	.A(from_sn_padded),
	.B(from_cpu_padded),
	.C(from_fwd_padded),
	.sel(ping_sel),
	.D(to_ping)
);

mux3 # (ADDR_WIDTH + `WRITE_WIDTH + 2*`ENABLE_BIT) pang_mux (
	.A(from_sn_padded),
	.B(from_cpu_padded),
	.C(from_fwd_padded),
	.sel(pang_sel),
	.D(to_pang)
);

mux3 # (ADDR_WIDTH + `WRITE_WIDTH + 2*`ENABLE_BIT) pung_mux (
	.A(from_sn_padded),
	.B(from_cpu_padded),
	.C(from_fwd_padded),
	.sel(pung_sel),
	.D(to_pung)
);

endmodule
