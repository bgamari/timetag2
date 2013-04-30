`timescale 1ns / 1ps

module test_hostif;

   // Inputs
   reg nrxf_i;
   reg ntxe_i;
   reg clk_i;
   reg reset_i;
   wire [7:0] omux_data_i;
   wire [0:0] omux_req_i;

   // Outputs
   wire      nrd_o;
   wire      wr_o;
   wire      si_o;
   wire [0:0] omux_sel_o;
   wire [15:0] reg_addr_o;
   wire        reg_wr_o;

   // Bidirs
   wire [7:0]  d_io;
   wire [31:0] reg_data_io;

   // Instantiate the Unit Under Test (UUT)
   host_iface uut (
		   .nrxf_i(nrxf_i), 
		   .ntxe_i(ntxe_i), 
		   .nrd_o(nrd_o), 
		   .wr_o(wr_o), 
		   .si_o(si_o), 
		   .d_io(d_io), 
		   .clk_i(clk_i), 
		   .reset_i(reset_i), 
		   .omux_data_i(omux_data_i), 
		   .omux_sel_o(omux_sel_o), 
		   .omux_req_i(omux_req_i), 
		   .reg_addr_o(reg_addr_o), 
		   .reg_data_io(reg_data_io), 
		   .reg_wr_o(reg_wr_o)
	           );

   wire [31:0] reg1_value;
   register #(.ADDR(16'h1))
   reg1(.reg_clk_i(clk_i),
	.reg_addr_i(reg_addr_o),
	.reg_data_io(reg_data_io),
	.reg_wr_i(reg_wr_o),
	.clk_i(clk_i),
	.reset_i(reset_i),
	.value_o(reg1_value)
	);

   readonly_register #(.ADDR(16'h2))
   reg2(.reg_clk_i(clk_i),
	.reg_addr_i(reg_addr_o),
	.reg_data_io(reg_data_io),
	.reg_wr_i(reg_wr_o),
	.value_i(32'hfeedbeef)
	);

   counter_register #(.ADDR(16'h3))
   reg3(.reg_clk_i(clk_i),
	.reg_addr_i(reg_addr_o),
	.reg_data_io(reg_data_io),
	.reg_wr_i(reg_wr_o),
	.reset_i(reset_i),
        .increment_clk_i(clk_i),
        .increment_i(1'b1)
	);

   reg [127:0] recbuf_rec_i;
   reg         recbuf_we_i;
   record_buffer recbuf(.clk_i(clk_i),
                        .reset_i(reset_i),
                        .rec_i(recbuf_rec_i),
                        .we_i(recbuf_we_i),
                        .omux_req_o(omux_req_i[0]),
                        .omux_sel_i(omux_sel_o[0]),
                        .omux_data_o(omux_data_i)
                        );
   

   initial clk_i = 0;
   always #10 clk_i = ~clk_i;
   
   // FT2232
   reg [7:0]   out_byte;
   assign d_io = nrd_o ? 8'hZZ : out_byte;
   always @(negedge wr_o) $display("Write %02x", d_io);

   // write byte to core
   task write_byte;
      input [7:0] b;
      begin
	 nrxf_i = 1'b0;
	 out_byte = b;
	 @(posedge nrd_o);
	 nrxf_i = 1'b1;
      end
   endtask
   
   // read byte from core
   task read_byte;
      output [7:0] b;
      begin
	 @(negedge wr_o);
	 b = d_io;
      end
   endtask
   
   task reg_cmd;
      input         write;
      input [15:0]  addr;
      input [31:0]  value;
      output [31:0] out;
      reg [7:0]     temp;
      begin
	 $display($time, "  Register transaction on %04x with value %08x (wr=%d)", addr, value, write);
	 write_byte(8'hAA);
	 write_byte({7'b0, write});
	 write_byte(addr[7:0]);
	 write_byte(addr[15:8]);
	 write_byte(value[7:0]);
	 write_byte(value[15:8]);
	 write_byte(value[23:16]);
	 write_byte(value[31:24]);
         read_byte(temp);
         if (temp != 8'hab) $display("Bad reply magic: %02x", temp);
	 read_byte(out[7:0]);
	 read_byte(out[15:8]);
	 read_byte(out[23:16]);
	 read_byte(out[31:24]);
	 $display($time, "  Register %04x = %08x", addr, out);
      end
   endtask

   // simulation
   reg [31:0] temp;
   initial begin
      // Initialize Inputs
      nrxf_i = 1; // RX empty
      ntxe_i = 0; // TX ready
      recbuf_we_i = 0;
      reset_i = 1;
      #200 reset_i = 0;

      // Wait 100 ns for global reset to finish
      #100 reg_cmd(1, 16'h1, 32'hdeadbeef, temp);   // write #1
      #200 reg_cmd(1, 16'h1, 32'h0000ffff, temp);   // write #2
      #300 reg_cmd(1, 16'h2, 32'h0000ffff, temp);   // read-only register
      #300 reg_cmd(0, 16'h3, 32'hffffffff, temp);   // counter register read
      #300 reg_cmd(1, 16'h3, 32'hffffffff, temp);   // counter register reset
      #400 reg_cmd(1, 16'h10, 32'h0000ffff, temp);  // non-existent register

      #1000 recbuf_rec_i = 128'heaeaeaeaeeaeaeaeaeaeaeaeaedaedaedeadaedeadeadeade;
      recbuf_we_i = 1;
      $display("hi");
      #2000 recbuf_we_i = 0;
      
   end
   

endmodule

