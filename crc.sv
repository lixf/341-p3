/** @file crc.sv
 *  @brief computes the CRC of the incoming bitstream, then attaches it to the
 *         end of the stream once we stop receiving bits.  
 *  @author Chris Williamson
 **/

`include "primitives.sv"

module crc
(input logic clk, rst_L,
 input logic pause_out,
 input logic inb, recving,
 output logic pause_in,
 output logic outb, sending);

  enum logic {IDLE, CALCCRC, SENDCRC} state, nextState;
  
  logic [4:0] crc_save;
  logic crc_outb, crc_done;
  logic crc5_x2_inb, crc5_x2_outb, crc5_x5_inb, crc5_x5_outb;
  logic shift_crc, init_crc;
  logic [3:0] curcount;
  logic clear_count, inc_count;

  /* TODO these need to reset to 1 each time we calculate a new crc */
  shift_reg #(2) crc5_x2(.out_full(crc_save[0:1]), .inb(crc_x2_inb), .outb(crc_x2_outb),
                         .en(shift_crc), .rst_b(reset_crc), .*);

  shift_reg #(3) crc5_x5(.out_full(crc_save[2:4]), .inb(crc_x5_inb), .outb(crc_x5_outb),
                         .en(shift_crc), .rst_b(reset_crc), .*);
  
  piso_shiftreg #(5) storedcrc(.D(crc_save), .ld_reg(crc_done), .clr_reg(0), 
                               .en(state == SENDCRC), .outb(crc_outb));

  counter #(4) outcrc_remaining(.inc_cnt(inc_count), .up(1),
                                .cnt(curcount), .clr_cnt(clear_count), .*);

  assign crc_x2_inb = crc_x5_outb ^ inb;
  assign crc_x5_inb = crc_x2_inb ^ crc_x2_outb;
  assign reset_crc = rst_L ? ~init_crc : rst_L;

  always_ff @(posedge clk, negedge rst_L)
  if (~rst_L)
    state <= IDLE;
  else
    state <= nextState;

  always_comb begin
    shift_crc = 0;
    init_crc = 0;
    pause_in = 0;
    outb = 0;
    sending = 0;
    crc_done = 0;
    /* counter control */
    clear_count = 0;
    inc_count = 0;

    case (state):
      IDLE: begin
        init_crc = 1;
        if (recving)
          nextState = CALCCRC;
      end
      CALCCRC: begin
        sending = 1;
        if (~pause_out)
          shift_crc = 1;
        outb = inb;
        if (~recving) begin
          crc_done = 1;
          outb = crc_outb;
          clear_count = 1;
          nextState = SENDCRC;
        end
      end
      SENDCRC: begin
        sending = 1;
        pause_in = 1;
        inc_count = 1;
        outb = crc_outb;
        if (curcount == 4)
          nextState = IDLE;
      end
    endcase

  end
