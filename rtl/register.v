// Fast Multisource Pulse Registration System
// Ben Gamari (2011)

module register(
	        input         reg_clk_i,
                input [15:0]  reg_addr_i,
                inout [31:0]  reg_data_io,
                input         reg_wr_i,
                      
	        input         clk_i,
                input         reset_i, 
                output [31:0] value_o
                );

   parameter ADDR = 1;
   parameter RESET_VALUE = 0;

   reg [31:0]                 value;

   initial value = 32'h0;

   always @(posedge reg_clk_i)
     if (reset_i)
       value <= RESET_VALUE;
     else if (reg_addr_i == ADDR && reg_wr_i)
       value <= reg_data_io;

   assign reg_data_io = (reg_addr_i == ADDR && !reg_wr_i) ? value : 32'hZZ;
endmodule


module readonly_register(
	                 input         reg_clk_i,
                         input [15:0]  reg_addr_i,
                         inout [31:0]  reg_data_io,
                         input         reg_wr_i,
                         input [31:0]  value_i
                         );

   parameter ADDR = 1;
   assign reg_data_io = (reg_addr_i == ADDR && !reg_wr_i) ? value_i : 32'hZZ;
endmodule


module counter_register(
	                input        reg_clk_i,
                        input [15:0] reg_addr_i,
                        inout [31:0] reg_data_io,
                        input        reg_wr_i,
	                 
                        input        reset_i,
                        input        increment_clk_i,
                        input        increment_i
                        );

   parameter ADDR = 1;
   
   reg [31:0]                        value;
   reg [31:0]                        my_value;
   initial my_value = 32'h0;

   reg                               needs_reset;
   initial needs_reset = 0;
   
   always @(posedge increment_clk_i)
     my_value <= (needs_reset || reset_i) ? 0 : my_value + increment_i;
   
   always @(posedge reg_clk_i)
     begin
	value <= my_value;
	if (reg_addr_i == ADDR && reg_wr_i)
	  needs_reset <= 1;
	else if (needs_reset)
	  needs_reset <= 0;
     end
   
   assign reg_data_io = (reg_addr_i == ADDR && !reg_wr_i) ? value : 32'hZZ;
endmodule
