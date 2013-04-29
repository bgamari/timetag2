module system (
               // Clock and control
               input        clkin_p,
               input        clkin_n,
               input        reset_i,
               output [3:0] led,

               // FT2232 interface
               input        nrxf_i,
               input        ntxe_i,
               output       nrd_o,
               output       wr_o,
               output       si_o,
               inout [7:0]  d_io,

               // TDC input
               input [1:0]  calib_i,

               // TDC output
               output [1:0] detect,
               output [1:0] polarity,
	       output       test_clk_oe_n,
	       output       test_clk_p,
	       output       test_clk_n,
	       output [1:0] tdc_signal_oe_n,
	       output [1:0] tdc_signal_term_en,
	       input [1:0]  tdc_signal_p,
	       input [1:0]  tdc_signal_n
               );

   wire                     sys_clk;
   wire [1:0]               tdc_signal;
   wire [1:0]               tdc_calib;
   wire [17:0]              raw;

   IBUFGDS clkbuf(.I(clkin_p),
	          .IB(clkin_n),
	          .O(sys_clk)
                  );

   timetagger tdc (.clk_i(sys_clk),
                   .reset_i(reset_i),

                   .nrxf_i(nrxf_i),
                   .ntxe_i(ntxe_i),
                   .nrd_o(nrd_o),
                   .wr_o(wr_o),
                   .si_o(si_i),
                   .d_io(d_io),
                   
                   .signal_i(tdc_signal),
                   .calib_i(tdc_calib),

                   .raw(raw),
                   .detect(detect),
                   .polarity(polarity)
                   );
   
   wire                     cal_clk16x;
   wire                     cal_clk;
   wire                     test_clk;
   tdc_ringosc #(.g_LENGTH(31))
   calib_osc (.en_i(~reset_i), .clk_o(cal_clk16x));
   
   // Divide down calibration clock
   reg [18:0]               cal_clkdiv;
   always @(posedge cal_clk16x) cal_clkdiv <= cal_clkdiv + 4'd1;
   assign cal_clk = cal_clkdiv[3];
   assign test_clk = cal_clkdiv[18];
   assign tdc_calib = {2{cal_clk}};

   assign test_clk_oe_n = 1'b0;
   OBUFDS obuf_test_clk(.O(test_clk_p),
	                .OB(test_clk_n),
	                .I(test_clk)
                        );

   assign tdc_signal_oe_n[0] = 1'b1;
   assign tdc_signal_term_en[0] = 1'b1;
   IBUFDS ibuf_tdc_signal0(.I(tdc_signal_p[0]),
	                   .IB(tdc_signal_n[0]),
	                   .O(tdc_signal[0])
                           );

   assign tdc_signal_oe_n[1] = 1'b1;
   assign tdc_signal_term_en[1] = 1'b0;
   IBUFDS ibuf_tdc_signal1(.I(tdc_signal_p[1]),
	                   .IB(tdc_signal_n[1]),
	                   .O(tdc_signal[1])
                           );

   assign led = 1;

endmodule