`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/29/2019 09:58:30 AM
// Design Name: 
// Module Name: packetramtb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

event test_writes, test_writes_done;
event test_enabled_reads, test_enabled_reads_done;
event test_disabled_reads_and_writes, test_disabled_reads_and_writes_done;

module packetramtb();
reg clk;
reg en; //clock enable

reg [9:0] addra;
reg [9:0] addrb;
wire [31:0] doa;
wire [31:0] dob;

reg [31:0] dia;
reg wr_en;

always #4 clk <= ~clk;

initial begin 
    clk <= 0;
    en <= 0;
    addra <= 0;
    addrb <= 0;
    dia <= 0;
    wr_en <= 0;
    #20
    ->test_writes;
    @(test_writes_done);
    
    #20
    ->test_enabled_reads;
    @(test_enabled_reads_done);
    
    #20
    ->test_disabled_reads_and_writes;
    @(test_disabled_reads_and_writes_done);
    
    #20
    ->test_enabled_reads;
    @(test_enabled_reads_done);
    
    #20
    $finish;
end

//Test writes
initial begin
    forever begin
        @(test_writes);
        @(negedge clk);
        en <= 1;
        wr_en <= 1;
        addra <= 0;
        dia <= 32'hDEADBEEF;
        @(negedge clk);
        addra <= 1;
        dia <= 32'hBEEFCAFE;
        @(negedge clk);
        addra <= 2;
        dia <= 32'hCAFEDEAD;
        @(negedge clk);
        en <= 0;
        wr_en <= 0;
        ->test_writes_done;
    end
end

//Test enable reads
initial begin
    forever begin
        @(test_enabled_reads);
        @(negedge clk);
        en <= 1;
        addra <= 0;
        addrb <= 2;
        @(negedge clk);
        addra <= 1;
        addrb <= 1;
        @(negedge clk);
        addra <= 2;
        addrb <= 0;
        @(negedge clk);
        en <= 0;
        ->test_enabled_reads_done;
    end
end

//Test disabled reads and writes
initial begin
    forever begin
        @(test_disabled_reads_and_writes);
        @(negedge clk);
        en <= 0; //Disable RAM
        wr_en <= 1; //Try writing 12345678 on port A...
        addra <= 0;
        dia <= 32'h12345678;
        addrb <= 2; //,,,while reading from port B
        @(negedge clk);
        addra <= 1;
        dia <= 32'h90ABCDEF;
        addrb <= 1;
        @(negedge clk);
        addra <= 0;
        dia <= 32'h55555555;
        addrb <= 2;
        @(negedge clk);
        wr_en <= 0;
        ->test_disabled_reads_and_writes_done;
    end
end


//D-doy, I need to instantiate the DUT
packetram DUT(
    .clk(clk),
    .en(en),
    .addra(addra),
    .addrb(addrb),
    .doa(doa),
    .dob(dob),
    .dia(dia),
    .wr_en(wr_en)
);

//Dumb initial value test
initial begin
    DUT.data[0] <= 32'h11111111;
    DUT.data[1] <= 32'h22222222;
    DUT.data[2] <= 32'h33333333;
end

endmodule
