`timescale 1ns / 1ps
/*
axistream_forwarder_tb.sv

Simple testbench for axistream_forwarder.v. Uses my new method of using .mem files
to specify test signals.
*/

module axistream_forwarder_tb();
reg [63:0] packet [0:9];
`define packet_len 1
`define ADDR_WIDTH 10
integer fd;

reg clk;
	
//AXI Stream interface
wire [63:0] TDATA;
wire TVALID;
wire TLAST;
reg TREADY;	

//Interface to packetmem
wire [`ADDR_WIDTH-1:0] forwarder_rd_addr;
reg [63:0] forwarder_rd_data = 0;
wire forwarder_rd_en;
wire forwarder_done; //NOTE: this must be a 1-cycle pulse.
reg ready_for_forwarder;
reg [31:0] len_to_forwarder;


initial begin
	$readmemh("axistream_forwarder_packet.mem", packet);
	fd = $fopen("axistream_forwarder_drivers.mem", "r");
	while($fgetc(fd) != "\n") begin end //Skip first line of comments
	
	clk <= 0;
	TREADY <= 0;
	forwarder_rd_data <= 0;
	ready_for_forwarder <= 0;
	len_to_forwarder <= `packet_len;
	
	#1
	
	@(posedge TLAST);
	@(posedge clk) $finish;
end

always #5 clk <= ~clk;

always @(posedge clk) begin
	if ($feof(fd)) begin
		$display("Reached end of drivers file");
		$finish;
	end
	$fscanf(fd, "%b%b", ready_for_forwarder, TREADY);
	if (forwarder_rd_en)
		forwarder_rd_data <= packet[forwarder_rd_addr];
end

axistream_forwarder #(
	.DATA_WIDTH(64),
	.ADDR_WIDTH(`ADDR_WIDTH),
	.PESSIMISTIC(1)
) DUT (
	.clk(clk),
	
	//AXI Stream interface
	.TDATA(TDATA),
	.TVALID(TVALID),
	.TLAST(TLAST),
	.TREADY(TREADY),	
	
	//Interface to packetmem
	.forwarder_rd_addr(forwarder_rd_addr),
	.forwarder_rd_data(forwarder_rd_data),
	.forwarder_rd_en(forwarder_rd_en),
	.forwarder_done(forwarder_done), //NOTE: this must be a 1-cycle pulse.
	.ready_for_forwarder(ready_for_forwarder),
	.len_to_forwarder(len_to_forwarder)
);

endmodule
