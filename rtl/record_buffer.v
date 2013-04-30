module record_buffer(
                     input clk_i,
                     input reset_i,

                     input [WIDTH-1:0] rec_i,
                     input we_i,

                     output omux_req_o,
                     input omux_sel_i,
                     output [7:0] omux_data_o
                     );

   parameter WIDTH = 128;   // record width in bytes (must be multiple of 8)
   parameter DEPTH = 32;    // number of records per buffer
   parameter NBUF = 4;      // number of buffers

   reg [$clog2(NBUF)-1:0]         write_buf;
   reg [$clog2(NBUF)-1:0]         read_buf;

   wire                           rd;
   wire [WIDTH-1:0]               out;

   wire [WIDTH-1:0]               read_out;
   wire                           read_empty, read_full;
   wire                           write_empty, write_full;

   genvar                         i;
   generate
     for (i=0; i<NBUF; i=i+1) begin:Buffers
        wire [WIDTH-1:0]   out;
        wire               empty;
        wire               full;

        generic_sync_fifo #(.g_data_width(WIDTH),
                            .g_size(DEPTH),
                            .g_almost_empty_threshold(0),
                            .g_almost_full_threshold(0),
                            .g_show_ahead(1))
        fifo1(.rst_n_i(~reset_i),
              .clk_i(clk_i),
              .d_i(rec_i),
              .we_i(we_i && write_buf==i && ~full),
              .q_o(out),
              .rd_i(rd && read_buf==i),
              .empty_o(empty),
              .full_o(full)
              );
        assign read_out = read_buf == i ? out : {(WIDTH){1'bZ}};
        assign read_empty = read_buf == i ? empty : 1'bz;
        assign read_full = read_buf == i ? full : 1'bz;
        assign write_empty = write_buf == i ? empty : 1'bZ;
        assign write_full = write_buf == i ? full : 1'bZ;
     end // for (i=0; i<NBUF; i=i+1)
   endgenerate

   function [$clog2(NBUF)-1:0] next_buffer;
      input [$clog2(NBUF)-1:0] i;
      begin
         next_buffer = (i + 1) % NBUF;
      end
   endfunction

   reg [1:0] read_state;
   reg [$clog2(WIDTH/8):0] read_pos; // oversized so comparisons work
   reg [WIDTH-1:0]         cur_rec;

   always @(posedge clk_i)
    if (reset_i) begin
       read_state <= 0;
       read_buf <= 0;
       write_buf <= 1;
    end else begin

        // (full && ~empty) ensures we handle reset correctly
        if (write_full && ~write_empty && next_buffer(write_buf) != read_buf)
          write_buf <= next_buffer(write_buf);

        case (read_state)
          // waiting for buffer to fill
          0 :
            if (read_empty && ~read_full && next_buffer(read_buf) != write_buf)
              read_buf <= next_buffer(read_buf);
            else
              read_state <= 1;

          // start reading out record
          1 :
            if (read_empty) begin
               read_state <= 0;
            end else begin
               read_pos <= 0;
               cur_rec <= read_out;
               read_state <= 2;
            end

          // read out bytes of record
          2 :
            if (read_empty) begin                   // buffer empty
               read_state <= 0;
            end else if (read_pos < WIDTH/8) begin  // More to read
               if (omux_sel_i) begin
                  cur_rec <= cur_rec >> 8;
                  read_pos <= read_pos + 1;
               end
            end else begin                          // done with record
               read_state <= 1;
            end

        endcase
     end

   assign rd = read_state == 1 && ~read_empty;

   assign omux_req_o = (read_state == 1 || read_state == 2) && ~read_empty;
   assign omux_data_o = omux_sel_i ? cur_rec[7:0] : 8'hZ;

endmodule
