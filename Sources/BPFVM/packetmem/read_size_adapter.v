`timescale 1ns / 1ps
/*

read_size_adapter.v

This is a fiddly bit of glue logic to enable the CPU to perform variable-sized
reads at (possibly) not-word-aligned address. I decided not to parameterize the
data widths since it's a very specific case (but the address widths are still
parameters). 

*/

//IMPORTANT: notice how the address is a combinational path, but that offset and
//sz are registered. This is no accident, and it is based on the assumption that
//the coderam needs only a single cycle to latch the address then to produce the
//data

//Assumes memory is 32 bits wide
//Assumes big-endianness


//Fetch size 
`define		BPF_W		2'b00 //Word, half-word, and byte
`define		BPF_H		2'b01
`define		BPF_B		2'b10

module read_size_adapter # (parameter
	BYTE_ADDR_WIDTH = 12 
)(
    input wire clk,
    input wire [BYTE_ADDR_WIDTH-1:0] byte_rd_addr,
    input wire [1:0] transfer_sz,
    output wire [BYTE_ADDR_WIDTH-2-1:0] word_rd_addra,
    //output wire [BYTE_ADDR_WIDTH-2-1:0] word_rd_addrb,
    
    //input wire [31:0] mem_rd_dataa,
    //input wire [31:0] mem_rd_datab,
    input wire [63:0] bigword,
    output wire [31:0] resized_mem_data //zero-padded on the left (when necessary)
);

assign word_rd_addra = byte_rd_addr[BYTE_ADDR_WIDTH-1:2];
//assign word_rd_addrb = byte_rd_addr[BYTE_ADDR_WIDTH-1:2] + 1;
//NOTE: this calculation was moved into packetram.v

//The offset into the 64 bit word returned
wire [1:0] offset;
assign offset = byte_rd_addr[1:0];

//Latch sz and offset. This, by the way, happens exactly the same time that
//the packetram latches the address
reg [1:0] sz_r, offset_r;
always @(posedge clk) begin
	sz_r <= transfer_sz;
	offset_r <= offset;
end

//This is written assuming packetram data width is 32
//We need to deal with the offset into the 64 bit word

//wire [63:0] bigword;
//assign bigword = {mem_rd_dataa, mem_rd_datab};
//NOTE: this calculation was moved into packetram.v

wire [31:0] offset0, offset1, offset2, offset3;
assign offset0 = bigword[63:32];
assign offset1 = bigword[63-8:32-8];
assign offset2 = bigword[63-16:32-16];
assign offset3 = bigword[63-24:32-24];

//This "selected" vector is the desired part of the 64-bit word, based on the offset
wire [31:0] selected;
assign selected = (offset_r[1] == 1'b1) ? (
                    (offset_r[0] == 1'b1) ? offset3 : offset2
                  ):( 
                    (offset_r[0] == 1'b1) ? offset1 : offset0
                  );

//odata is zero-padded if you ask for a smaller size
assign resized_mem_data[7:0] = (sz_r == `BPF_W) ? selected[7:0]: 
								((sz_r == `BPF_H) ? selected[23:16] : selected[31:24]); 

assign resized_mem_data[15:8] = (sz_r == `BPF_W) ? selected[15:8]: 
								((sz_r == `BPF_H) ? selected[31:24] : 0);

assign resized_mem_data[31:16] = (sz_r == `BPF_W) ? selected[31:16]: 0;

endmodule