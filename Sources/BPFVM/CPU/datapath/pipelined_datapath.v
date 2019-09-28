`timescale 1ns / 1ps
/*
bpfvm_datapath.v

This implements the datapath of the BPF processor. It includes the accumulator (A)
and auXiliary (X) register as defined by the BSD Packet Filter spec. (Note: there is
no actual spec; I just looked through the C files in the libpcap git repo). It also
includes an ALU (defined in alu.v) and scratch memory (defined in regfile.v).

This file is not super easy to read; I recommend using Vivado's auto-generated
schematic (in the "Elaborated Design") to see what this file is supposed to do. 
Actually, in order to write this file, I actually drew out what I wanted then
fiddled with the verilog until the schematic matched my drawing. 

This pipelined datapath is inteneded to be controlled by the pipelined_bpfvm_ctrl 
moduyle.

This datapath is actually a bunch of parallel pipelined modules, each with its own
separate schedule. See pipelined_alu.v for a description of its schedule. Below are
the schedules of the rest of the datapath (and everything else is combinational). All
schedules have an II of 1.

NOTE: sometimes you will see immN used in a schedule: to understand what this means,
see the "Complicated business with the immediate" section

Reading from packet memory:
--------------------------
C0: (Input: addr_sel; Output: none)
Writes either X or imm1 into packet_rd_addr register

C1: (Input: packmem_rd_en*, transfer_sz*; Output: packmem_rd_addr)
The packet_rd_addr register is output, and packmem_rd_en should be asserted (if necessary)

C2: (Input: none; Output: packmem_rd_data**)
The packet memory has single-cycle access time, and the rd_data is ready

*packmem_rd_en and transfer_sz are directly output by the controller
**is actually an input to this module, but it made sense to think of it as an output here

Updating A/X/PC:
---------------
C0: (Input: QQ_sel, QQ_en; Output: QQ)
All registers (and memories) have the property that you can use the old value, even
if their write enable is asserted (which will cause their value to update at the next
clock edge). Note that A and X are updated from imm3 and PC is updated from imm2

C1: (Input: none; Output: none)
The register's value is updated.

Updating a register in the register file:
----------------------------------------
C0: (Input: imm2, regfile_wr_en; Output: none)
regfile_sel selects whether A or X is used as the write value, and imm selects 
which register to write into.

C1: (Input: none; Output: none)
regfile[imm2@C0] = regfile_sel@C0 ? A@C0 : X@C0;

Reading from the register file (in order to write to A or X):
------------------------------------------------------------
C0: (Input: imm2; Output:none)
The output of regfile[imm2] is saved in a register

C1: (Input: none; Output: regfile[imm2@C0])

Complicated business of the immediate:
-------------------------------------
The immediate is the only value which could be used at any point in the pipeline.
This isn't really a "schedule", but it was helpful for me to sketch it out. Note 
that I have named the imm value at each part of its schedule

C0: (Input: mem_rd_en, mem_rd_addr; Output: none)
The immediate from a new instruction will be ready at the next clock edge
Note: this step is not performed in the datapath

C1: (Input: imm1, B_sel, addr_sel; Output: ALU operand B)
Note: if pipeline should stall here, note that the fetch stage will continue
to feed in the old immediate value again.
Note: imm1 is used for ALU operand B and for packet rd addr.
imm2 will be loaded with imm1 at the next clock edge

C2: (Input: regfile_wr_en; Output: packmem_rd_addr, imm2)
regfile_wr_en will decide if regfile[imm2] will be updated. Note that packmem_rd_addr
becomes ready here (I've superimposed part of the packmem_rd_addr's schedule here)
imm3 will be loaded with imm2 at the next clock edge

C3: (Input: A_sel, A_en, X_sel, X_en; Output: A, X, imm3)
Basically, the immediate could be used as a new value for A or X, and it
could also be used to index into the register file (in order to update A
or X with that regfile register).

*/

module pipelined_bpfvm_datapath # (parameter
	CODE_ADDR_WIDTH = 10,
	CODE_DATA_WIDTH = 64,
	PACKET_BYTE_ADDR_WIDTH = 12,
	PESSIMISTIC = 0
)(
    input wire rst,
    input wire clk,
    input wire [2:0] A_sel,
    input wire [2:0] X_sel,
    input wire [1:0] PC_sel,
    input wire addr_sel,
    input wire A_en,
    input wire X_en,
    input wire PC_en,
    input wire PC_rst,
    input wire B_sel,
    input wire [3:0] ALU_sel,
    input wire [CODE_DATA_WIDTH-1:0] inst_mem_data,
    input wire [31:0] packet_data, //This will always get padded to 32 bits
    input wire [31:0] packet_len, //Hardcoded. Should left-pad with zeroes automatically
    input wire regfile_wr_en,
    input wire regfile_sel,
    output wire [15:0] opcode,
    output wire set,
    output wire eq,
    output wire gt,
    output wire ge,
    output wire [PACKET_BYTE_ADDR_WIDTH-1:0] packet_addr,
    output reg [CODE_ADDR_WIDTH-1:0] PC = 0,
    output wire A_is_zero,
    output wire X_is_zero,
    output wire imm_lsb_is_zero
);

reg [31:0] A, X; //A is the accumulator, X is the auxiliary register
wire [31:0] B; //ALU's second operand
wire [31:0] ALU_out;
wire [CODE_DATA_WIDTH-1:0] IR;  //Instruction register
assign IR = inst_mem_data; //Note: this is just a rename

reg [CODE_ADDR_WIDTH-1:0] nextPC = 0; //This better not be a (clocked) register!

wire [7:0] jt, jf; //These are named subfields of the IR value
wire [31:0] imm;

assign opcode = IR[63:48];
assign jt = IR[47:40];
assign jf = IR[39:32];
assign imm = IR[31:0];

//This implements the "complicated imm business schedule"
wire [31:0] imm1;
reg [31:0] imm2; //PIPELINE REGISTER
wire [31:0] imm2_n;
reg [31:0] imm3; //PIPELINE REGISTER
wire [31:0] imm3_n;

assign imm1 = imm;
assign imm2_n = imm1;
assign imm3_n = imm2;

always @(posedge clk) begin
	if (rst) begin
		imm2 <= 0;
		imm3 <= 0;
	end else begin
		imm2 <= imm2_n;
		imm3 <= imm3_n;
	end
end

//Forward-declare wire
wire [31:0] scratch_odata;

//Named constants for A register MUX
`ifndef A_SEL_IMM
`define		A_SEL_IMM 	3'b000
`endif 
`define		A_SEL_ABS	3'b001
`define		A_SEL_IND	3'b010 
`define		A_SEL_MEM	3'b011
`define		A_SEL_LEN	3'b100
`define		A_SEL_MSH	3'b101
`define		A_SEL_ALU	3'b110
`define		A_SEL_X		3'b111
//Accumulator's new value
always @(posedge clk) begin
    if (A_en == 1'b1) begin
        case (A_sel)
            3'b000:
                A <= imm3; //Note use of imm3
            3'b001:
                A <= packet_data;
            3'b010:
                A <= packet_data; //Hmmmm... both ABS and IND addressing wire packet_data to A
            3'b011:
                A <= scratch_odata; 
            3'b100:
                A <= packet_len;
            3'b101:
                A <= {26'b0, imm3[3:0], 2'b0}; //TODO: No MSH instruction is defined (by bpf) for A. Should I leave this?
            3'b110:
                A <= ALU_out;
            3'b111: //for TXA instruction
                A <= X;
        endcase
    end
end

//Named constants for X register MUX
`define		X_SEL_IMM 	3'b000 
`define		X_SEL_ABS	3'b001
`define		X_SEL_IND	3'b010 
`define		X_SEL_MEM	3'b011
`define		X_SEL_LEN	3'b100
`define		X_SEL_MSH	3'b101
`define		X_SEL_A		3'b111
//Auxiliary (X) register's new value
always @(posedge clk) begin
    if (X_en == 1'b1) begin
        case (X_sel)
            `X_SEL_IMM:
                X <= imm3; //Note use of imm3
            `X_SEL_ABS:
                X <= packet_data;
            `X_SEL_IND:
                X <= packet_data; //Hmmmm... both ABS and IND addressing wire packet_data to X
            `X_SEL_MEM:
                X <= scratch_odata;
            `X_SEL_LEN:
                X <= packet_len;
            `X_SEL_MSH:
                X <= {26'b0, packet_data[3:0], 2'b0};
            `X_SEL_A: //for TAX instruction
                X <= A;
            default:
                X <= 0; //Does this even make sense?
        endcase
    end
end

//Program counter's new value
always @(posedge clk) begin
    if (PC_rst == 1'b1) begin
        PC <= 0;
    end else if (PC_en == 1'b1) begin
        PC <= nextPC;
    end
end

always @(*) begin
    case (PC_sel)
        2'b00:
            nextPC <= PC + 1;
        2'b01:
            nextPC <= PC + jt; //TODO: sign-extend jt and jf?
        2'b10:
            nextPC <= PC + jf; 
        2'b11:
            nextPC <= PC + imm2; //TODO: sign-extend imm? 
            //Note the use of imm2
    endcase
end

wire [PACKET_BYTE_ADDR_WIDTH-1:0] packet_addr_internal;

//packet_addr mux. Note use of imm1
assign packet_addr_internal = (addr_sel == 1'b0) ? imm1 : (X+imm1);

//This implements C0 for the packet address schedule
reg [PACKET_BYTE_ADDR_WIDTH-1:0] packet_addr_r = 0; //PIPELINE REGISTER
always @(posedge clk) begin
	if (rst) packet_addr_r <= 0;
	else packet_addr_r <= packet_addr_internal;
end

//This implements C1 for the packet address schedule
//packmem_rd_en is output by the controller
assign packet_addr = packet_addr_r;

//ALU operand B select
assign B = (B_sel == 1'b1) ? X : imm1; //Note use of imm1

pipelined_alu # (
	.PESSIMISTIC(PESSIMISTIC)
) myalu (
	.clk(clk),
    .A(A),
    .B(B),
    .ALU_sel(ALU_sel),
    .ALU_out(ALU_out),
    .eq(eq),
    .gt(gt),
    .ge(ge),
    .set(set)
    );

wire [31:0] scratch_odata_internal;
wire [31:0] scratch_idata;

assign scratch_idata = (regfile_sel == 1'b1) ? X : A;

regfile scratchmem (
    .clk(clk),
    .rst(rst),
    .addr(imm2[3:0]), //This implements C2 in the immediate's schedule
    .idata(scratch_idata),
    .odata(scratch_odata_internal),
    .wr_en(regfile_wr_en)
);

reg [31:0] scratch_odata_r; //PIPELINE REGISTER
always @(posedge clk) begin
	if (rst) begin
		scratch_odata_r <= 0;
	end else begin
		scratch_odata_r <= scratch_odata_internal;
	end 
end

assign A_is_zero = (A == 0);
assign X_is_zero = (X == 0);
assign imm_lsb_is_zero = ~imm1[0]; //Very quick-n-dirty hack to get rid of
//maybe one or two LUTs in a failing combinational path

endmodule
