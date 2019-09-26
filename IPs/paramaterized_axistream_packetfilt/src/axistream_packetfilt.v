`timescale 1ns / 1ps
/*
axistream_packetfilt.v

Represents one particular variation of the FPGA-BPF. This one uses AXILite to control
whether the machine is started/stopped, as well as to send in new instructions. It also
includes an AXI Stream snooper and forwarder.
*/

`define PACKET_DATA_WIDTH (2**(3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH))
//God what a mess... need to fix the packet length soon!
`define PLEN_WIDTH (SNOOP_FWD_ADDR_WIDTH+1)

module axistream_packetfilt # (
    parameter AXI_ADDR_WIDTH = 32, // width of the AXI address bus
    parameter [31:0] BASEADDR = 32'h00000000, // the register file's system base address
    parameter CODE_ADDR_WIDTH = 10, // codemem depth = 2^CODE_ADDR_WIDTH
    parameter PACKET_BYTE_ADDR_WIDTH = 12, // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    parameter SNOOP_FWD_ADDR_WIDTH = 9,
    //this makes the data width of the snooper and fwd equal to:
    // 2^{3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH}
    parameter N = 5 //Number of parallel BPFVMs
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
    
	//AXI Stream interface for forwarder
	output wire [`PACKET_DATA_WIDTH-1:0] fwd_TDATA, //Registered in another module
	output wire fwd_TVALID,
	output wire fwd_TLAST,
	input wire fwd_TREADY,
	
	//AXI Stream interface
	input wire [`PACKET_DATA_WIDTH-1:0] snoop_TDATA,
	input wire snoop_TVALID,
	input wire snoop_TREADY, //Yes, this is an input. Remember that we're snooping!
	input wire snoop_TLAST
);
    
//Interface to snooper
wire [SNOOP_FWD_ADDR_WIDTH-1:0] snooper_wr_addr;
wire [`PACKET_DATA_WIDTH-1:0] snooper_wr_data; 
wire snooper_wr_en;
wire snooper_done; //NOTE: this must be a 1-cycle pulse.
wire ready_for_snooper;

//Interface to forwarder
wire [SNOOP_FWD_ADDR_WIDTH-1:0] forwarder_rd_addr;
wire [`PACKET_DATA_WIDTH-1:0] forwarder_rd_data;
wire forwarder_rd_en;
wire forwarder_done; //NOTE: this must be a 1-cycle pulse.
wire ready_for_forwarder;
wire [`PLEN_WIDTH-1:0] len_to_forwarder;

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
wire [CODE_ADDR_WIDTH-1:0] code_mem_wr_addr;
wire [63:0] code_mem_wr_data; //Instructions are always 64 bits wide
wire code_mem_wr_en; 

parallel_packetfilts # (
    .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH),
    .PACKET_BYTE_ADDR_WIDTH(PACKET_BYTE_ADDR_WIDTH),
    .SNOOP_FWD_ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH),
    .N(N)
) theFilter (   
	// Clock and Reset
	.axi_aclk(axi_aclk),
	.rst(!axi_aresetn || !control_start),
    
    //Interface to snooper
	.snooper_wr_addr(snooper_wr_addr),
	.snooper_wr_data(snooper_wr_data),
	.snooper_wr_en(snooper_wr_en),
	.snooper_done(snooper_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_snooper(ready_for_snooper),
    
	//Interface to forwarder
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder),
	.len_to_forwarder(len_to_forwarder),
	
	//Interface to codemem
	.code_mem_wr_addr(code_mem_wr_addr),
	.code_mem_wr_data(code_mem_wr_data), //Instructions are always 64 bits wide
	.code_mem_wr_en(code_mem_wr_en)
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

axistream_snooper # (
	.DATA_WIDTH(`PACKET_DATA_WIDTH),
	.ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH)
) el_snoopo (
	.clk(axi_aclk),
	
	//AXI Stream interface
	.TDATA(snoop_TDATA),
	.TVALID(snoop_TVALID),
	.TREADY(snoop_TREADY), //Yes, this is an input. Remember that we're snooping!
	.TLAST(snoop_TLAST),
	
	//Interface to packet mem
	.wr_addr(snooper_wr_addr),
	.wr_data(snooper_wr_data),
	.mem_ready(ready_for_snooper),
	.wr_en(snooper_wr_en),
	.done(snooper_done)
);

axistream_forwarder # (
	.DATA_WIDTH(`PACKET_DATA_WIDTH),
	.ADDR_WIDTH(SNOOP_FWD_ADDR_WIDTH)
) forward_unto_dawn (
	.clk(axi_aclk),
	
	//AXI Stream interface
	.TDATA(fwd_TDATA), //Registered in another module
	.TVALID(fwd_TVALID),
	.TLAST(fwd_TLAST),
	.TREADY(fwd_TREADY),	
	
	//Interface to packetmem
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder),
	.len_to_forwarder(len_to_forwarder)
);
endmodule

`undef PACKET_DATA_WIDTH
`undef PLEN_WIDTH