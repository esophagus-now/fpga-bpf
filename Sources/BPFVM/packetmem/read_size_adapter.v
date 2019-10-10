`timescale 1ns / 1ps
/*

read_size_adapter.v

This is a fiddly bit of glue logic to enable the CPU to perform variable-sized
reads at (possibly) not-word-aligned address. I decided not to parameterize the
data widths since it's a very specific case (but the address widths are still
parameters). 

REGULAR MODE
Schedule (II=1):
C0: (Input: packmem_rd_en, transfer_sz, byte_rd_addr; Output: word_rd_addra)
Note that the bigword input in C1 is the read data from the packet memory 

C1: (Input: bigword; Output: resized_mem_data)

PESSIMISTIC ADAPTER MODE
Schedule (II=1):
C0: (Input: packmem_rd_en, transfer_sz, byte_rd_addr; Output: word_rd_addra)
Note that the bigword input in C1 is the read data from the packet memory 

C1: (Input: bigword; Output: none)

C2: (Input: none; Output: resized_mem_data)

PESSIMISTIC BRAM MODE
Schedule (II=1):
C0: (Input: packmem_rd_en, transfer_sz, byte_rd_addr; Output: word_rd_addra)
Note that the bigword input in C2 is the read data from the packet memory 

C1: (Input: none; Output: none)

C2: (Input: bigword; Output: resized_mem_data)

PESSMISTIC MODE
Schedule (II=1):
C0: (Input: packmem_rd_en, transfer_sz, byte_rd_addr; Output: word_rd_addra)
Note that the bigword input in C2 is the read data from the packet memory 

C1: (Input: none; Output: none)

C2: (Input: bigword; Output: none)

C3: (Input: none; Output: resized_mem_data)


*/

//IMPORTANT: notice how the address is a combinational path, but that offset and
//sz are registered. This is no accident, and it is based on the assumption that
//the coderam needs only a single cycle to latch the address then to produce the
//data

//Assumes memory is 32 bits wide
//Assumes big-endianness


`include "bpf_defs.vh"

//I kept needing this quantity in the code
`define N (PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH)
`define PORT_DATA_WIDTH (2**(`N+2))

module read_size_adapter # (
    parameter PACKET_BYTE_ADDR_WIDTH = 12, // packetmem depth = 2^PACKET_BYTE_ADDR_WIDTH
    parameter SNOOP_FWD_ADDR_WIDTH = 9,
    //this makes the data width of the snooper and fwd equal to:
    // 2^{3 + PACKET_BYTE_ADDR_WIDTH - SNOOP_FWD_ADDR_WIDTH}
    //Because of the support for unaligned reads, I actually use two ports of half the size
    parameter PESSIMISTIC = 0
)(
    input wire clk,
    input wire [PACKET_BYTE_ADDR_WIDTH-1:0] byte_rd_addr,
    input wire [1:0] transfer_sz,
    output wire [SNOOP_FWD_ADDR_WIDTH+1-1:0] word_rd_addra,
    
    input wire [2*`PORT_DATA_WIDTH-1:0] bigword,
    output wire [31:0] resized_mem_data //zero-padded on the left (when necessary)
);

wire [31:0] resized_mem_data_internal;

assign word_rd_addra = byte_rd_addr[PACKET_BYTE_ADDR_WIDTH-1 : `N - 1];

//The offset into the 2*PORT_DATA_WIDTH bit word returned from the packet memory
wire [`N-2:0] offset;
assign offset = byte_rd_addr[`N-2:0];

//Latch sz and offset. This, by the way, happens exactly the same time that
//the packetram latches the address (and produces the read data)
reg [1:0] sz_r;
reg [`N-2:0] offset_r;
always @(posedge clk) begin
	sz_r <= transfer_sz;
	offset_r <= offset;
end

//This is written assuming packetram data width is 32
//We need to deal with the offset into the 64 bit word

//This "selected" vector is the desired part of the 64-bit word, based on the offset
wire [31:0] selected;
assign selected = bigword[(2*`PORT_DATA_WIDTH - {offset_r, 3'b0} )-1 -: 32];

//odata is zero-padded if you ask for a smaller size
assign resized_mem_data_internal[7:0] = (sz_r == `BPF_W) ? selected[7:0]: 
								((sz_r == `BPF_H) ? selected[23:16] : selected[31:24]); 

assign resized_mem_data_internal[15:8] = (sz_r == `BPF_W) ? selected[15:8]: 
								((sz_r == `BPF_H) ? selected[31:24] : 0);

assign resized_mem_data_internal[31:16] = (sz_r == `BPF_W) ? selected[31:16]: 0;

////////////////////////////////////////
////////// PESSIMISTIC MODE ////////////
////////////////////////////////////////
generate
if (PESSIMISTIC) begin
	reg [31:0] resized_mem_data_r = 0;
	always @(posedge clk) begin
		resized_mem_data_r = resized_mem_data_internal;
	end
	assign resized_mem_data = resized_mem_data_r;
end
///////////////////////////////////////
////////// OPTIMISTIC MODE ////////////
///////////////////////////////////////
else begin
	assign resized_mem_data = resized_mem_data_internal;
end
endgenerate
///////////////////////////////////////

endmodule

`undef N
`undef PORT_DATA_WIDTH