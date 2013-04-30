`timescale 1ns / 1ps

module ft2232(
              // FT2232 interface
              input        nrxf_i,
              input        ntxe_i,
              output       nrd_o,
              output       wr_o,
              output       si_o,
              inout [7:0]  d_io,

              // Internal interface
              input        clk_i,
              input        reset_i,

              //   Outgoing data (to host)
              input [7:0]  out_data_i,
              input        out_req_i,
              output       out_ack_o,

              //   Incoming data (from host)
              output [7:0] in_data_o,
              output       in_rdy_o
              );

   // FT2232 needs at least 50ns between bytes
   parameter WAIT_STATES = 10;

   initial active_out_buffer = 0;
   reg                     active_out_buffer;
   wire [7:0]              out_d;

   // Scale clock down for FT2232
   initial rescaled_clk = 0;
   reg                     rescaled_clk;
   initial wait_state = 0;
   reg [$clog2(WAIT_STATES):0] wait_state;

   always @(posedge rescaled_clk)
     begin
        if (wait_state == 0) begin
           rescaled_clk <= ~rescaled_clk;
           wait_state <= WAIT_STATES;
        end else begin
           wait_state <= wait_state - 1;
        end
     end

   // FT2232 interface state machine
   initial state = 0;
   reg [2:0]               state;

   always @(posedge clk_i)
   begin
      if (reset_i) state <= 0;
      else case (state)
       // Idle
       3'd00 :
         begin
            if (~nrxf_i)
              state <= 3'd01;
            else if (~ntxe_i & out_req_i)
              state <= 3'd03;
         end

       // Read incoming data
       3'd01 : state <= 3'd02;
       // Advance incoming data
       3'd02 :
         begin
            if (nrxf_i) state <= 3'd00;
            else state <= 3'd01;
        end

       // Write outgoing data
       3'd03 : state <= 3'd04;
       // Latch outgoing data
       3'd04 :
         begin
            if (~ntxe_i & out_req_i) state <= 3'd03;
            else state <= 3'd00;
         end
     endcase
   end

   assign nrd_o = state != 3'd01;
   assign wr_o = state != 3'd04;
   assign d_io = (state == 3'd03 || state == 3'd04) ? out_data_i : 8'bZZ;
   assign si_o = 1'b1;

   assign out_ack_o = state == 3'd04;
   assign in_rdy_o = state == 3'd01;
   assign in_data_o = d_io;

endmodule
