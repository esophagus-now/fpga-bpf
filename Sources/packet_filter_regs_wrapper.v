`timescale 1ns / 1ps
/*
packet_filter_regs_wrapper.v

For some reason, you can't use SystemVerilog in IP Integrator. However, if you wrap it
in a Verilog file, it will work. This is beyond foolish, but anyway it has to be done.

*/


module packet_filter_regs_wrapper#(
    parameter AXI_ADDR_WIDTH = 32, // width of the AXI address bus
    parameter [31:0] BASEADDR = 32'h00000000 // the register file's system base address 
) (
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
    
    // User Ports          
    output wire status_strobe, // Strobe logic for register 'Status' (pulsed when the register is read from the bus)
    input wire [15:0] status_num_packets_dropped, // Value of register 'Status', field 'num_packets_dropped'
    output wire control_strobe, // Strobe logic for register 'Control' (pulsed when the register is written from the bus)
    output wire [0:0] control_start, // Value of register 'Control', field 'start'
    output wire inst_low_strobe, // Strobe logic for register 'inst_low' (pulsed when the register is written from the bus)
    output wire [31:0] inst_low_value, // Value of register 'inst_low', field 'value'
    output wire inst_high_strobe, // Strobe logic for register 'inst_high' (pulsed when the register is written from the bus)
    output wire [31:0] inst_high_value // Value of register 'inst_high', field 'value'
    );
    

packet_filter_regs #(
	.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH), // width of the AXI address bus
	.BASEADDR(BASEADDR) // the register file's system base address 
) wrapped (
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

endmodule
