//OLD TESTBENCH FILE! WILL NOT WORK WITH NEWER PACKETMEM.V!

`timescale 1ns / 1ps

/*

packetmemtb.sv

This testbench verifies the functionality of packetmem.v. 

*/


module packetmemtb();


`define		BPF_W		2'b00 //Word, half-word, and byte
`define		BPF_H		2'b01
`define		BPF_B		2'b10


`define DATA_WIDTH 32
`define BYTE_ADDR_WIDTH 12 
`define ADDR_WIDTH 10

reg clk;
reg [`BYTE_ADDR_WIDTH-1:0] rd_addr;
reg [1:0] sz; //00 for byte (8b), 01 for half-word (16b), or 10 for word (32b)
reg rd_en; 

wire [`DATA_WIDTH-1:0] odata; //Always padded to 32 bits (left padded with zeros)

reg [`ADDR_WIDTH-1:0] wr_addr;
reg [`DATA_WIDTH-1:0] idata;
reg wr_en;

always #5 clk <= ~clk;

event write_vals, write_vals_done;
event read_vals, read_vals_done;

//Main driver
initial begin
    clk <= 0;
    rd_en <= 0;
    wr_en <= 0;
    rd_addr <= 0;
    wr_addr <= 0;
    sz <= 0;
    idata <= 0;
    
    #20
    ->write_vals;
    @(write_vals_done);
    
    #20
    ->read_vals;
    @(read_vals_done);
    
    #20
    $finish;
end

//Write values into the packet memory
initial begin
    forever begin
        @(write_vals);
        @(negedge clk);
        wr_en <= 1;
        wr_addr <= 0;
        idata <= 32'h01234567;
        @(negedge clk);
        wr_addr <= 1;
        idata <= 32'h89ABCDEF;
        @(negedge clk);
        wr_addr <= 2;
        idata <= 32'h55555555;
        @(negedge clk);
        wr_en <= 0;
        ->write_vals_done;
    end
end

//Do some various-sized and possibly unaligned reads
initial begin
    forever begin
        @(read_vals);
        @(negedge clk);
        rd_en <= 1;
        rd_addr <= 0;
        sz <= `BPF_W; //For 32 bit read
        @(negedge clk);
        rd_addr <= 1;
        @(negedge clk);
        rd_addr <= 2;
        @(negedge clk);
        sz <= `BPF_B; //8 bit read
        @(negedge clk);
        rd_addr <= 3;
        sz <= `BPF_H; //16 bit read
        @(negedge clk);
        rd_en <= 0;
        ->read_vals_done;
    end
end

//Instantiate the device under test 
packetmem DUT (
    .clk(clk),
    .rd_addr(rd_addr),
    .sz(sz),
    .rd_en(rd_en),
    .odata(odata),
    .wr_addr(wr_addr),
    .idata(idata),
    .wr_en(wr_en)
);


endmodule
