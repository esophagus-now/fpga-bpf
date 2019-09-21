`timescale 1ns / 1ps
/*
packetfilt.v

Intended to be a top-level module for a packaged IP. For now, it only grafts an AXI 
slave onto the interface for adding new instructions. In the future, it should also
include some way to add a parameterizable number of snoopers as well as manage their
configuration.
*/

//TODO: Should these be parameters? And by the way, there are a lot of hardcoded widths
`define CODE_ADDR_WIDTH 10
`define CODE_DATA_WIDTH 64 
`define PACKET_BYTE_ADDR_WIDTH 12
`define PACKET_ADDR_WIDTH (`PACKET_BYTE_ADDR_WIDTH - 2)

module packetfilt # (
    parameter AXI_ADDR_WIDTH = 32, // width of the AXI address bus
    parameter [31:0] BASEADDR = 32'h00000000 // the register file's system base address 
)(

    // Clock and Reset
    input  wire                      axi_aclk,
    input  wire                      axi_aresetn,
                                     
    // AXI Write Address Channel     
    input  wire [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire [2:0]                s_axi_awprot,
    input  wire                      s_axi_awvalid,
    output wire                      s_axi_awready,
                                     
    // AXI Write Data Channel        
    input  wire [31:0]               s_axi_wdata,
    input  wire [3:0]                s_axi_wstrb,
    input  wire                      s_axi_wvalid,
    output wire                      s_axi_wready,
                                     
    // AXI Read Address Channel      
    input  wire [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
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
    
    //Interface to snooper
    input wire [`PACKET_ADDR_WIDTH-1:0] snooper_wr_addr,
	input wire [63:0] snooper_wr_data, //Hardcoded to 64 bits. TODO: change this to a parameter?
	input wire snooper_wr_en,
	input wire snooper_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_snooper,
    
	//Interface to forwarder
	input wire [`PACKET_ADDR_WIDTH-1:0] forwarder_rd_addr,
	output wire [63:0] forwarder_rd_data,
	input wire forwarder_rd_en,
	input wire forwarder_done, //NOTE: this must be a 1-cycle pulse.
	output wire ready_for_forwarder,
	output wire [`PACKET_ADDR_WIDTH-1:0] len_to_forwarder
);

    
// User Ports          
wire status_strobe; // Strobe logic for register 'Status' (pulsed when the register is read from the bus)
wire [15:0] status_num_packets_dropped; // Value of register 'Status'; field 'num_packets_dropped'
wire control_strobe; // Strobe logic for register 'Control' (pulsed when the register is written from the bus)
wire [0:0] control_start; // Value of register 'Control'; field 'start'
wire inst_low_strobe; // Strobe logic for register 'inst_low' (pulsed when the register is written from the bus)
wire [31:0] inst_low_value; // Value of register 'inst_low'; field 'value'
wire inst_high_strobe; // Strobe logic for register 'inst_high' (pulsed when the register is written from the bus)
wire [31:0] inst_high_value; // Value of register 'inst_high'; field 'value'


//Interface to codemem
wire [`CODE_ADDR_WIDTH-1:0] code_mem_wr_addr;
wire [`CODE_DATA_WIDTH-1:0] code_mem_wr_data;
wire code_mem_wr_en;

regstrb2mem read_inst_regs (
	.clk(axi_aclk),

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

packet_filter_regs #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH), // width of the AXI address bus
    .BASEADDR(BASEADDR) // the register file's system base address 
) regmap (
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
    
    // User Ports          
	.status_strobe(status_strobe), // Strobe logic for register 'Status' (pulsed when the register is read from the bus)
	.status_num_packets_dropped(status_num_packets_dropped), // Value of register 'Status', field 'num_packets_dropped'
	.control_strobe(control_strobe), // Strobe logic for register 'Control' (pulsed when the register is written from the bus)
	.control_start(control_start), // Value of register 'Control', field 'start'
	.inst_low_strobe(inst_low_strobe), // Strobe logic for register 'inst_low' (pulsed when the register is written from the bus)
	.inst_low_value(inst_low_value), // Value of register 'inst_low', field 'value'
	.inst_high_strobe(inst_high_strobe), // Strobe logic for register 'inst_high' (pulsed when the register is written from the bus)
	.inst_high_value(inst_high_value) // Value of register 'inst_high', field 'value'
);


bpfvm the_VM(
	.rst(!axi_aresetn || !control_start), //Reset should be high if resetn is LOW or if start is LOW 
	.clk(axi_aclk),
	//Interface to an external module which will fill codemem
	.code_mem_wr_addr(code_mem_wr_addr),
	.code_mem_wr_data(code_mem_wr_data),
	.code_mem_wr_en(code_mem_wr_en),
    
    //Interface to snooper
	.snooper_wr_addr(snooper_wr_addr),
	.snooper_wr_data(snooper_wr_data), //Hardcoded to 32 bits. TODO: change this to 64?
	.snooper_wr_en(snooper_wr_en),
	.snooper_done(snooper_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_snooper(ready_for_snooper),
    
	//Interface to forwarder
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder),
	.len_to_forwarder(len_to_forwarder)
);

endmodule
