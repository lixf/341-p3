/** @file bitstream_dec.sv
 *  @brief The bitstream decoder for serial input
 *  @author Chris Williamson
 **/


module bitstream_decoder
(input logic clk, rst_L,
 input logic pause, recving, inb,
 output logic [63:0] data,
 output logic havepkt, error, haveack, havenak);

  enum logic [2:0] {IDLE, RECV_PKT, EOP1,EOP2,SEND_PKT} state, nextState;
  /* shift registers */
  logic [87:0] pkt_out;
  logic [7:0] saved_pid;
  logic shift_pkt, shift_pid;
  logic clr_reg;
  /* counter */
  logic [7:0] curcount;
  logic count, clrcounter;
  /* CRC control */
  logic [87:0] crcpkt_out;
  logic crc_outb, crc_enable, crc_reset_L;
  logic crc_sending, crc_pause_in, crc_clear;

  enum logic [3:0] {OUT = 4'b1000, IN = 4'b1001, DATA0 = 4'b1100,
                    ACK = 4'b0100, NAK = 4'b0101} current_pid;

  /* Big shift register to hold the entire incoming packet. */
  sipo_shiftreg #(88) packet_reg(.inb(inb), .Q(pkt_out),
                             .clr_reg(clr_reg), .en(shift_pkt), .*);
  /* Store just the PID separately so that we can do the right thing based on
   * what type of packet this is (and error-check the PID bits) */
  sipo_shiftreg #(8) pid_reg(.inb(inb), .Q(saved_pid),
                             .clr_reg(clr_reg), .en(shift_pid), .*);

  /* bit counter - Keep track of the number of bits in the packet to ensure
   * that it is the correct length */
  counter #(8) total_bytes(.inc_cnt(count), .clr_cnt(clrcounter), .up(1'b1),
                           .cnt(curcount),.rst_b(rst_L),.*);
  
  /* Calculate CRC while reading the packet in, so we can verify the CRC is 
   * equal after we're done reading. */
  crc crc_checker(.pause_out(pause), .pkttype(saved_pid[7:4] == DATA0),
                  .start(curcount < 8), .outb(crc_outb), .sending(crc_sending),
                  .recving(crc_enable), .clear(crc_clear), .pause_in(crc_pause_in), .*);
  sipo_shiftreg #(88) crcpkt_reg(.inb(crc_outb), .Q(crcpkt_out),
                                 .clr_reg(clr_reg), .en(shift_pkt), .*);

  always_ff @(posedge clk, negedge rst_L)
  if (~rst_L)
    state <= IDLE;
  else
    state <= nextState;
    
  always_comb begin
    /* packet register control points */
    shift_pkt = 0;
    shift_pid = 0;
    clr_reg = 0;
    clrcounter = 0;
    count = 0;
    nextState = state;
    /* CRC control */
    crc_clear = 1;
    crc_enable = 0;
    /* outputs */
    data = 0;
    havepkt = 0;
    error = 0;
    haveack = 0;
    havenak = 0;

    case (state)
      IDLE: begin
        if (recving && ~pause) begin
          count = 1;
          shift_pkt = 1;
          shift_pid = 1;
          nextState = RECV_PKT;
        end
        else begin
          clrcounter = 1;
          clr_reg = 1;
          //crc_clear = 1;
        end
      end
      RECV_PKT: begin
        if (~pause) begin
          count = 1;
          shift_pkt = 1;
          crc_enable = 1;
          /* For the first 8 bits, record the PID.  For the rest of the packet
           * up until the CRC, feed bits to the CRC module. */
          if (curcount < 8)
            shift_pid = 1;
          else if (saved_pid[7:4] == DATA0 && curcount > 72)
            crc_enable = 0;
          /*
          else if ((saved_pid[3:0] == OUT || saved_pid[3:0] == IN)
                   && curcount > 19)
            crc_enable = 0;
          */

          if (~recving) begin
            shift_pkt = 0;
            shift_pid = 0;
            count = 0;
            nextState = EOP1;
          end
        end
      end

      EOP1:
        nextState = EOP2;

      EOP2:
        nextState = SEND_PKT;


      /* If the packet is valid, send it.  If we notice that something is
       * wrong, send an error instead */
      SEND_PKT: begin
        if (saved_pid[3:0] != ~saved_pid[7:4])
          /* Invalid PID */
          error = 1;

        else if (saved_pid[7:4] == ACK)
          if (curcount == 8)
            haveack = 1;
          else
            /* Invalid packet length */
            error = 1;

        else if (saved_pid[7:4] == NAK)
          if (curcount == 8)
            havenak = 1;
          else
            /* Invalid packet length */
            error =1;
        else if (saved_pid[7:4] == DATA0) begin
          if (curcount == 88) begin
            if (pkt_out[15:0] != crcpkt_out[15:0])
              /* Bad CRC */
              error = 1;
            else begin
              havepkt = 1;
              data = pkt_out[80:16];
            end
          end
          else
            /* Invalid packet length */
            error = 1;
        end
        else
          /* Invalid PID */
          error = 1;

        nextState = IDLE;
      end
    endcase

  end
endmodule: bitstream_decoder
