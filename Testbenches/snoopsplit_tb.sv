`timescale 1ns / 1ps
/*
snoopsplit_tb.sv

Tests three snoop splitters arranged in a tree:

                      __ A
            __split1_/
           /         \__ B
          /(left)
  split0_/
         \
          \(right)    __ C
           \__split2_/
                     \__ D


*/  

`define DATA_WIDTH 64
`define ADDR_WIDTH 10

`define SHORT_DELAY repeat(5) @(posedge clk)
`define LONG_DELAY repeat(10) @(posedge clk)
`define SYNC @(posedge clk)

module snoopsplit_tb();

reg clk;

//Snooper outputs (inputs into split0)
reg [`ADDR_WIDTH-1:0] wr_addr;
reg [`DATA_WIDTH-1:0] wr_data;
wire mem_ready;
reg wr_en;
reg done;

//BPFVM backpressure signals
reg mem_ready_A;
reg mem_ready_B;
reg mem_ready_C;
reg mem_ready_D;

//Split 0 "outputs" (inputs into split1 and split 2)
wire [`ADDR_WIDTH-1:0] wr_addr_left_split0;
wire [`DATA_WIDTH-1:0] wr_data_left_split0;
wire mem_ready_left_split0;
wire wr_en_left_split0;
wire done_left_split0;
wire [`ADDR_WIDTH-1:0] wr_addr_right_split0;
wire [`DATA_WIDTH-1:0] wr_data_right_split0;
wire mem_ready_right_split0;
wire wr_en_right_split0;
wire done_right_split0;
wire choice_split0;

//Split1 outputs
wire [`ADDR_WIDTH-1:0] wr_addr_left_split1;
wire [`DATA_WIDTH-1:0] wr_data_left_split1;
wire wr_en_left_split1;
wire done_left_split1;
wire [`ADDR_WIDTH-1:0] wr_addr_right_split1;
wire [`DATA_WIDTH-1:0] wr_data_right_split1;
wire wr_en_right_split1;
wire done_right_split1;
wire choice_split1;

//Split2 outputs
wire [`ADDR_WIDTH-1:0] wr_addr_left_split2;
wire [`DATA_WIDTH-1:0] wr_data_left_split2;
wire wr_en_left_split2;
wire done_left_split2;
wire [`ADDR_WIDTH-1:0] wr_addr_right_split2;
wire [`DATA_WIDTH-1:0] wr_data_right_split2;
wire wr_en_right_split2;
wire done_right_split2;
wire choice_split2;

initial begin
	clk <= 0;
	wr_addr <= 0;
	wr_data <= 0;
	wr_en <= 0;
	done <= 0;
	mem_ready_A <= 1;
	mem_ready_B <= 1;
	mem_ready_C <= 1;
	mem_ready_D <= 1;
end

always #5 clk <= ~clk;

always @(posedge clk) begin
	wr_addr <= wr_addr + 1;
	wr_data <= $random;
	wr_en <= $random;
end

initial begin
	`LONG_DELAY;
	done <= 1; //finished writing into A; B should be selected
	`SYNC;
	done <= 0;
	mem_ready_A <= 0;
	
	`LONG_DELAY;
	done <= 1; //finished writing into B; C should be selected
	`SYNC;
	done <= 0;
	mem_ready_B <= 0;
	
	`SHORT_DELAY;
	mem_ready_A <= 1; //A becomes ready...
	
	`SHORT_DELAY;
	done <= 1; //finished writing into C; A should be selected
	`SYNC;
	done <= 0;
	mem_ready_C <= 0;
	
	`LONG_DELAY;
	done <= 1; //finished writing into A; D should be selected
	`SYNC;
	done <= 0;
	mem_ready_A <= 0;
	
	`LONG_DELAY;
	done <= 1; //finished writing into D; everything should stop now
	`SYNC;
	done <= 0;
	mem_ready_D <= 0;
	
	`SHORT_DELAY;
	`LONG_DELAY;
	mem_ready_C <= 1; //C should be immediately selected
	
	`LONG_DELAY;
	$finish;
end

snoopsplit # (
	.DATA_WIDTH(`DATA_WIDTH),
	.ADDR_WIDTH(`ADDR_WIDTH)
) split0 (
	.clk(clk),
	//Interface to packet mem as the output of the snooper (or previous split stage)
	.wr_addr(wr_addr),
	.wr_data(wr_data),
	.mem_ready(mem_ready),
	.wr_en(wr_en),
	.done(done),
	
	//Interface to packet mem as the input of the VM (or next split stage)
	.wr_addr_left(wr_addr_left_split0),
	.wr_data_left(wr_data_left_split0),
	.mem_ready_left(mem_ready_left_split0),
	.wr_en_left(wr_en_left_split0),
	.done_left(done_left_split0),
	.wr_addr_right(wr_addr_right_split0),
	.wr_data_right(wr_data_right_split0),
	.mem_ready_right(mem_ready_right_split0),
	.wr_en_right(wr_en_right_split0),
	.done_right(done_right_split0),
	
	//Output which branch we chose which is later used to put packets back into
	//the right order
	.choice(choice_split0)
);

snoopsplit # (
	.DATA_WIDTH(`DATA_WIDTH),
	.ADDR_WIDTH(`ADDR_WIDTH)
) split1 (
	.clk(clk),
	//Interface to packet mem as the output of the snooper (or previous split stage)
	.wr_addr(wr_addr_left_split0),
	.wr_data(wr_data_left_split0),
	.mem_ready(mem_ready_left_split0),
	.wr_en(wr_en_left_split0),
	.done(done_left_split0),
	
	//Interface to packet mem as the input of the VM (or next split stage)
	.wr_addr_left(wr_addr_left_split1),
	.wr_data_left(wr_data_left_split1),
	.mem_ready_left(mem_ready_A),
	.wr_en_left(wr_en_left_split1),
	.done_left(done_left_split1),
	.wr_addr_right(wr_addr_right_split1),
	.wr_data_right(wr_data_right_split1),
	.mem_ready_right(mem_ready_B),
	.wr_en_right(wr_en_right_split1),
	.done_right(done_right_split1),
	
	//Output which branch we chose which is later used to put packets back into
	//the right order
	.choice(choice_split1)
);

snoopsplit # (
	.DATA_WIDTH(`DATA_WIDTH),
	.ADDR_WIDTH(`ADDR_WIDTH)
) split2 (
	.clk(clk),
	//Interface to packet mem as the output of the snooper (or previous split stage)
	.wr_addr(wr_addr_right_split0),
	.wr_data(wr_data_right_split0),
	.mem_ready(mem_ready_right_split0),
	.wr_en(wr_en_right_split0),
	.done(done_right_split0),
	
	//Interface to packet mem as the input of the VM (or next split stage)
	.wr_addr_left(wr_addr_left_split2),
	.wr_data_left(wr_data_left_split2),
	.mem_ready_left(mem_ready_C),
	.wr_en_left(wr_en_left_split2),
	.done_left(done_left_split2),
	.wr_addr_right(wr_addr_right_split2),
	.wr_data_right(wr_data_right_split2),
	.mem_ready_right(mem_ready_D),
	.wr_en_right(wr_en_right_split2),
	.done_right(done_right_split2),
	
	//Output which branch we chose which is later used to put packets back into
	//the right order
	.choice(choice_split2)
);
endmodule
