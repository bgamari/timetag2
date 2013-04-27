// (c) Ben Gamari (2013)

module reg_manager(
	           input         clk_i,
                   input         reset_i,

                   // ft2232 interface
	           input         in_rdy_i,
                   input [7:0]   in_data_i,

	           output [7:0]  omux_data_o,
                   output        omux_req_o,
                   input         omux_sel_i,
	                        
                   // internal register interface
	           output [15:0] reg_addr_o,
                   inout [31:0]  reg_data_io,
                   output        reg_wr_o
);

   reg [15:0]                    addr;
   reg [31:0]                    data;
   reg                           wants_wr;

   initial state = 0;
   reg [4:0]                     state;

   always @(posedge clk_i)
     begin
        if (reset_i) state <= 0;
        else case (state)
	       0:   if (in_rdy_i && in_data_i == 8'hAA)	// Read magic number
		          state <= 1;

	       1:   if (in_rdy_i)			// Read message type (read/write)
		 begin
		    wants_wr <= in_data_i[0];
		    state <= 2;
		 end

	       // Read address
	       2:   if (in_rdy_i)			// 1st byte
		 begin
		    addr[7:0] <= in_data_i;
		    state <= 3;
		 end
	       3:   if (in_rdy_i)			// 2nd byte
		 begin
		    addr[15:8] <= in_data_i;
		    state <= 4;
		 end

	       // Read value
	       4:   if (in_rdy_i)			// 1st byte
		 begin
		    data[7:0] <= in_data_i;
		    state <= 5;
		 end
	       5:   if (in_rdy_i)			// 2nd byte
		 begin
		    data[15:8] <= in_data_i;
		    state <= 6;
		 end
	       6:   if (in_rdy_i)			// 3rd byte
		 begin
		    data[23:16] <= in_data_i;
		    state <= 7;
		 end
	       7:   if (in_rdy_i)			// 4th byte
		 begin
		    data[31:24] <= in_data_i;
		    state <= 8;
		 end

	       // Write new value to register (if needed)
	       8:   state <= 9;

	       // Write reply to host
               9:   if (omux_sel_i) state <= 9;
               10:  if (omux_sel_i) state <= 11;  // 1st byte
	       11:  if (omux_sel_i) state <= 12;  // 2nd byte
	       12:  if (omux_sel_i) state <= 13;  // 3rd byte
	       13:  if (omux_sel_i) state <= 0;   // 4th byte
	       
	       default: state <= 0;
             endcase
     end

   assign reg_addr_o = (state==8 || state==9 || state==10 || state==11 || state==12) ? addr : 16'hXX;
   assign reg_data_io = (state==8) ? data : 32'hZZ;
   assign reg_wr_o = (state==8) && wants_wr;

   assign omux_data_o = (state==9)  ? reg_data_io[7:0] : 
		        (state==10) ? reg_data_io[15:8] :
		        (state==11) ? reg_data_io[23:16] :
		        (state==12) ? reg_data_io[31:24] : 8'hZZ;
   assign omux_req_o = state==9 || state==10 || state==11 || state==12 || state==13;

endmodule

