`timescale 1ns / 1ps

/* host_iface: Host interface
 * 
 * This module is responsible for providing a reasonably clean
 * abstraction of the FT2232 interface to the tagger logic.
 */
module host_iface(
                  // FT2232 interface
                  input               nrxf_i,
                  input               ntxe_i,
                  output              nrd_o,
                  output              wr_o,
                  output              si_o,
                  inout [7:0]         d_io,

                  
                  // Internal interface
                  input               clk_i,
                  input               reset_i,

                  // Outgoing data (to host)
                  input [7:0]         omux_data_i,
                  output [N_SRCS-1:0] omux_sel_o,
                  input [N_SRCS-1:0]  omux_req_i,

                  // Register interface
                  output [15:0]       reg_addr_o,
                  inout [31:0]        reg_data_io,
                  output              reg_wr_o
                  );

   parameter N_SRCS = 1;
   
   wire [7:0]                         in_data;
   wire [7:0]                         out_data;
   wire                               out_req;
   wire                               out_ack;
   
   ft2232 ft(.nrxf_i(nrxf_i),
             .ntxe_i(ntxe_i),
             .nrd_o(nrd_o),
             .wr_o(wr_o),
             .si_o(si_o),
             .d_io(d_io),

             .clk_i(clk_i),
             .reset_i(reset_i),

             .out_data_i(out_data),
             .out_req_i(out_req),
             .out_ack_o(out_ack),

             .in_data_o(in_data),
             .in_rdy_o(in_rdy)
             );

   wire [7:0]                         omux_data;
   wire [N_SRCS-1:0]                  omux_req;
   wire [N_SRCS-1:0]                  omux_sel;
   
   out_mux #(.N_SRCS(N_SRCS))
   outmux(.clk_i(clk_i),
          .reset_i(reset_i),

          .omux_data_i(omux_data),
          .omux_req_i(omux_req),
          .omux_sel_o(omux_sel),

          .out_o(out_data),
          .out_req_o(out_req),
          .out_ack_i(out_ack)
          );

   reg_manager regman(.clk_i(clk_i),
                      .reset_i(reset_i),
                      
                      .in_data_i(in_data),
                      .in_rdy_i(in_rdy),
 
                      .omux_data_o(omux_data),
                      .omux_req_o(omux_req[0]),
                      .omux_sel_i(omux_sel[0]),
 
                      .reg_addr_o(reg_addr_o),
                      .reg_data_io(reg_data_io),
                      .reg_wr_o(reg_wr_o)
                      );
   
endmodule


/* output multiplexer
 * 
 * Both register manager replies and the data stream need to be
 * multiplexed through the USB interface.
 * 
 * When a writer wants to write, he sets his bit in omux_req_i. When
 * the mux is ready to take his data, it sets his omux_sel_o bit at
 * which point he drives omux_data_i with the data to write. When the
 * sender has finished, he should de-assert his request pin as he
 * sends the last byte.
 */
module out_mux(
               input               clk_i,
               input               reset_i,

               // Outgoing data (to host)
               output [7:0]        out_o,
               output              out_req_o,
               input               out_ack_i,
               
               // Internal writer interface
               input [7:0]         omux_data_i,
               input [N_SRCS-1:0]  omux_req_i,
               output [N_SRCS-1:0] omux_sel_o
               );
   
   parameter N_SRCS = 1;

   initial current_src = 0;
   reg [$clog2(N_SRCS):0]             current_src;
   reg [$clog2(N_SRCS):0]             j;
   
   initial state = 0;
   reg [1:0]                          state;
   
   always @(posedge clk_i)
     begin
        if (reset_i) begin
           current_src <= 0;
           state <= 0;
        end
        else case (state)
               // idle
               0 : 
                  if (omux_req_i != 0) begin
                     state <= 1;
                     for (j=0; j < N_SRCS; j = j + 1)
                        if (omux_req_i[N_SRCS - j - 1])
                          current_src <= N_SRCS - j - 1;
                  end

               // send a byte
               1 :
                 if (~omux_req_i[current_src])
                   state <= 0;
                 else
                   state <= 2;
               
               // wait for ack
               2 :
                 if (out_ack_i)
                   state <= omux_req_i[current_src] ? 1 : 0;
                    
            endcase
     end
   
   assign omux_sel_o = (state == 2 && out_ack_i) ? (1 << current_src) : 0;
   assign out_o = omux_data_i;
   assign out_req_o = state == 1;
   
endmodule