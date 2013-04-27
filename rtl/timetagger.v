module timetagger (
                   input clk_i,
                   input reset_i,

                   input [CHANNEL_COUNT-1:0] calib_i,
                   input [CHANNEL_COUNT-1:0] signal_i,

                   output [CHANNEL_COUNT-1:0] detect,
                   output [CHANNEL_COUNT*RAW_COUNT-1:0] raw
                   );

   parameter CHANNEL_COUNT = 2;   // Number of channels
   parameter CARRY_COUNT = 124;   // Number of CARRY4 elements per channel
   parameter RAW_COUNT = 9;       // Number of raw output bits
   parameter FP_COUNT = 13;       // Number of fractional part bits
   
   host_iface hostif();

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
   
   wire [CHANNEL_COUNT-1:0]                  detect;
   wire [CHANNEL_COUNT-1:0]                  polarity;

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
            .fp_o(fp)
            );
        
endmodule

  