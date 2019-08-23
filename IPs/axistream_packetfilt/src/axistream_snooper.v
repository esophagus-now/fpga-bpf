`timescale 1ns / 1ps
/*
axistream_snooper.v

A simple snooper for AXI Stream wires. 
*/


module axistream_snooper # (parameter
	DATA_WIDTH = 32,
	ADDR_WIDTH = 10
)(
	input wire clk,
	
	//AXI Stream interface
	input wire [DATA_WIDTH-1:0] TDATA,
	input wire TVALID,
	input wire TREADY, //Yes, this is an input. Remember that we're snooping!
	input wire TLAST,
	
	//Interface to packet mem
	output wire [ADDR_WIDTH-1:0] wr_addr,
	output wire [DATA_WIDTH-1:0] wr_data,
	input wire mem_ready,
	output wire wr_en,
	output wire done
);

//We should make this wait for a packet to start, right?
//As in, wait for TLAST, and only then start copying

//To be even more specific: the problem occurs when TREADY and TVALID are 1
//(meaning new data went through the bus) but mem_ready was low

reg need_to_wait = 0;
wire next_need_to_wait;
assign next_need_to_wait = TLAST ? 0 : ((TVALID && TREADY && !mem_ready) ? 1 : need_to_wait);
always @(posedge clk) need_to_wait <= next_need_to_wait;

assign wr_data = TDATA; //TODO: make this work for arbitrary widths

reg [ADDR_WIDTH-1:0] addr = 0;
wire [ADDR_WIDTH-1:0] next_addr;

assign wr_en = (mem_ready && TVALID && TREADY && !need_to_wait);

//make done = 1 on our last write
assign done = TLAST && wr_en;

assign next_addr = wr_en ? (done ? 0 : addr + 1) : addr;

always @(posedge clk) begin
	addr <= next_addr;
end

assign wr_addr = addr;

endmodule
