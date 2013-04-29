module timetagger (
                   // Clock and control
                   input                                clk_i,
                   input                                reset_i,

                   // FT2232 interface
                   input                                nrxf_i,
                   input                                ntxe_i,
                   output                               nrd_o,
                   output                               wr_o,
                   output                               si_o,
                   inout [7:0]                          d_io,

                   // TDC input
                   input [CHANNEL_COUNT-1:0]            calib_i,
                   input [CHANNEL_COUNT-1:0]            signal_i,

                   // TDC output
                   output [CHANNEL_COUNT-1:0]           detect,
                   output [CHANNEL_COUNT-1:0]           polarity,
                   output [CHANNEL_COUNT*RAW_COUNT-1:0] raw
                   );

   parameter CHANNEL_COUNT = 2;   // Number of channels
   parameter CARRY_COUNT = 124;   // Number of CARRY4 elements per channel
   parameter RAW_COUNT = 9;       // Number of raw output bits
   parameter FP_COUNT = 13;       // Number of fractional part bits
   
   wire [15:0]                                          reg_addr;
   wire [31:0]                                          reg_data;
   wire                                                 reg_wr;

   wire [7:0]                                           omux_data;
   wire                                                 omux_sel;
   wire                                                 omux_req;
   
   readonly_register #(.ADDR(16'h1))
   version_reg(.reg_clk_i(clk_i),
               .reg_addr_i(reg_addr),
               .reg_data_io(reg_data),
               .reg_wr_i(reg_wr),
               .value_i(32'h01)
               );
   
   host_iface hostif(.nrxf_i(nrxf_i),
                     .ntxe_i(ntxe_i),
                     .nrd_o(nrd_o),
                     .wr_o(wr_o),
                     .si_o(si_o),
                     .d_io(d_io),

                     .clk_i(clk_i),
                     .reset_i(reset_i),

                     .omux_data_i(omux_data),
                     .omux_sel_o(omux_sel),
                     .omux_req_i(omux_req),

                     .reg_addr_o(reg_addr),
                     .reg_data_io(reg_data),
                     .reg_wr_o(reg_wr)
                     );

   wire [31:0]                               tdc_reg;
   register #(.ADDR(16'h10))
   tdcreg(.reg_clk_i(clk_i),
          .reg_addr_i(reg_addr),
          .reg_data_io(reg_data),
          .reg_wr_i(reg_wr),

          .clk_i(clk_i),
          .reset_i(reset_i),
          .value_o(tdc_reg)
          );
   
   wire [75:0]                                deskew;
   wire [75:0]                                fp;
   
   tdc #(.g_CHANNEL_COUNT(CHANNEL_COUNT),
         .g_CARRY4_COUNT(CARRY_COUNT),
         .g_RAW_COUNT(RAW_COUNT),
         .g_FP_COUNT(FP_COUNT)
        )
   cmp_tdc (.clk_i(clk_i),
            .reset_i(reset_i),
            .ready_o(tdc_ready),
            
            .cc_rst_i(tdc_reg[0]),
            .cc_cy_o(cc_cy),
            
            .deskew_i(deskew),
            .signal_i(signal_i),
            .calib_i(calib_i),
            
            .detect_o(detect),
            .polarity_o(polarity),
            .raw_o(raw),
            .fp_o(fp),

            // debug interface
            .lut_a_i(9'b0),
            .his_a_i(9'b0),
            .freeze_req_i(1'b0),
            .cs_next_i(1'b0),
            .calib_sel_i(1'b0),
            .oc_start_i(1'b0)
            );
        
   // Write-out
   reg [3:0]                                 state;
   reg [97:0]                                time_buffer;
   
   always @(posedge clk_i) begin
      if (reset_i)
        state <= 0;
      else if (state == 0) begin
         if (detect != 0) begin
            time_buffer <= {polarity, detect, raw, fp};
            state <= 1;
         end
      end
      else if (state == 6)
        state <= 0;
      else begin
         if (omux_sel) begin
            time_buffer <= time_buffer >> 8;
            state <= state + 1;
         end
      end
   end
   
   // FIXME
   assign omux_data = state == 0 ? 8'hZ : time_buffer[7:0];
   assign omux_req = state != 0;
    
endmodule

