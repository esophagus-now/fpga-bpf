`timescale 1ns / 1ps
/*
axistream_packetfilt.v

Represents one particular variation of the FPGA-BPF. This one uses AXILite to control
whether the machine is started/stopped, as well as to send in new instructions. It also
includes an AXI Stream snooper and forwarder.
*/


`define AXI_ADDR_WIDTH 12
`define CODE_ADDR_WIDTH 10
`define PACKET_BYTE_ADDR_WIDTH 12
`define SNOOP_FWD_ADDR_WIDTH 8

module top # (
//this makes the data width of the snooper and fwd equal to:
// 2^{3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH}
localparam PACKET_DATA_WIDTH = 2**(3 + `PACKET_BYTE_ADDR_WIDTH - `SNOOP_FWD_ADDR_WIDTH)
)(
    // Clock and Reset
    input  wire                      axi_aclk,
    input  wire                      axi_aresetn,
                                     
    // AXI Write Address Channel     
    input  wire [`AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire [2:0]                s_axi_awprot,
    input  wire                      s_axi_awvalid,
    output wire                      s_axi_awready,
                                     
    // AXI Write Data Channel        
    input  wire [31:0]               s_axi_wdata,
    input  wire [3:0]                s_axi_wstrb,
    input  wire                      s_axi_wvalid,
    output wire                      s_axi_wready,
                                     
    // AXI Read Address Channel      
    input  wire [`AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire [2:0]                s_axi_arprot,
    input  wire                      s_axi_arvalid,
    output wire                      s_axi_arready,
                                     
    // AXI Read Data Channel         
    output wire [31:0]               s_axi_rdata,
    output wire [1:0]                s_axi_rresp,
    output wire                      s_axi_rvalid,
    input  wire                      s_axi_rready,
                                     
    // AXI Write Response Channel    
    output wire [1:0]                s_axi_bresp,
    output wire                      s_axi_bvalid,
    input  wire                      s_axi_bready,
    
	//AXI Stream interface for forwarder
	output wire [PACKET_DATA_WIDTH-1:0] fwd_TDATA, //Registered in another module
	output wire fwd_TVALID,
	output wire fwd_TLAST,
	input wire fwd_TREADY,
	
	//AXI Stream interface
	input wire [PACKET_DATA_WIDTH-1:0] snoop_TDATA,
	input wire snoop_TVALID,
	input wire snoop_TREADY, //Yes, this is an input. Remember that we're snooping!
	input wire snoop_TLAST
);

axistream_packetfilt # (
	.AXI_ADDR_WIDTH(`AXI_ADDR_WIDTH), // width of the AXI address bus
	.CODE_ADDR_WIDTH(`CODE_ADDR_WIDTH), // codemem depth = 2^CODE_ADDR_WIDTH
	.PACKET_BYTE_ADDR_WIDTH(`PACKET_BYTE_ADDR_WIDTH), // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
	.SNOOP_FWD_ADDR_WIDTH(`SNOOP_FWD_ADDR_WIDTH)
) DUT (

    // Clock and Reset
	.axi_aclk(axi_aclk),
	.axi_aresetn(axi_aresetn),
                                     
    // AXI Write Address Channel     
	.s_axi_awaddr(s_axi_awaddr),
	.s_axi_awprot(s_axi_awprot),
	.s_axi_awvalid(s_axi_awvalid),
	.s_axi_awready(s_axi_awready),
                                     
    // AXI Write Data Channel        
	.s_axi_wdata(s_axi_wdata),
	.s_axi_wstrb(s_axi_wstrb),
	.s_axi_wvalid(s_axi_wvalid),
	.s_axi_wready(s_axi_wready),
                                     
    // AXI Read Address Channel      
	.s_axi_araddr(s_axi_araddr),
	.s_axi_arprot(s_axi_arprot),
	.s_axi_arvalid(s_axi_arvalid),
	.s_axi_arready(s_axi_arready),
                                     
    // AXI Read Data Channel         
	.s_axi_rdata(s_axi_rdata),
	.s_axi_rresp(s_axi_rresp),
	.s_axi_rvalid(s_axi_rvalid),
	.s_axi_rready(s_axi_rready),
                                     
    // AXI Write Response Channel    
	.s_axi_bresp(s_axi_bresp),
	.s_axi_bvalid(s_axi_bvalid),
	.s_axi_bready(s_axi_bready),
    
	//AXI Stream interface for forwarder
	.fwd_TDATA(fwd_TDATA), //Registered in another module
	.fwd_TVALID(fwd_TVALID),
	.fwd_TLAST(fwd_TLAST),
	.fwd_TREADY(fwd_TREADY),
	
	//AXI Stream interface
	.snoop_TDATA(snoop_TDATA),
	.snoop_TVALID(snoop_TVALID),
	.snoop_TREADY(snoop_TREADY), //Yes this is an input. Remember that we're snooping!
	.snoop_TLAST(snoop_TLAST)
);  

endmodule
