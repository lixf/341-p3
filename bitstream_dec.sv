/** @file bitstream_dec.sv
 *  @brief The bitstream decoder for serial input
 *  @author Chris Williamson
 **/


module bitstream_decoder
(input logic clk, rst_L,
 input logic pause, recving, inb, got_data,
 output logic [3:0] pid, [6:0] addr, [63:0] data, [3:0] endp,
 output logic havepkt, error, haveack, havenak);

  enum logic [2:0] {IDLE, RECV, SEND_SYNC, 
              SEND_PID, SEND_ADDR, SEND_DATA, SEND_ENDP} state, nextState;
  /* shift registers */
  logic [87:0] pkt_out;
  logic [7:0] saved_pid;
  logic shift_pkt, shift_pid;
  logic clr_reg;
  /* counter */
  logic [7:0] curcount;
  logic count, clrcounter;

  enum logic [3:0] {OUT = 4'b0001, IN = 4'b1001, DATA0 = 4'b0011,
                    ACK = 4'b0010, NAK = 4'b1010} current_pid;

  /* Big shift register to hold the entire incoming packet. */
  sipo_shiftreg #(88) packet_reg(.rst_b(rst_L), .inb(inb), .Q(pkt_out),
                             .clr_reg(clr_reg), .en(shift_pkt), .*);
  /* Store just the PID separately so that we can do the right thing based on
   * what type of packet this is (and error-check the PID bits) */
  sipo_shiftreg #(8) pid_reg(.rst_b(rst_L), .inb(inb), .Q(saved_pid),
                             .clr_reg(clr_reg), .en(shift_pid), .*);

  /* bit counter - Keep track of the number of bits in the packet to ensure
   * that it is the correct length */
  counter #(8) total_bytes(.inc_cnt(count), .clr_cnt(clrcounter), .up(1'b1),
                               .cnt(curcount),.rst_b(rst_L),.*);

  always_ff @(posedge clk, negedge rst_L)
  if (~rst_L)
    state <= IDLE;
  else
    state <= nextState;
    
  always_comb begin
    /* Control points */
    shift_pkt = 0;
    shift_pid = 0;
    clr_reg = 0;
    clrcounter = 0;
    count = 0;
    nextState = state;
    /* outputs */
    pid = 0;
    addr = 0;
    data = 0;
    endp = 0;
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
        end
      end
      RECV_PKT: begin
        if (~pause) begin
          count = 1;
          shift_pkt = 1;
          if (curcount < 8)
            shift_pid = 1;
          if (~recving) begin
            shift_pkt = 0;
            shift_pid = 0;
            count = 0;
            nextState = SEND_PKT;
          end
        end
      end
      /* If the packet is valid, send it.  If we notice that something is
       * wrong, send an error instead */
      SEND_PKT: begin
        if (saved_pid[3:0] != ~saved_pid[7:4])
          error = 1;

        else if (saved_pid[3:0] == ACK)
          if (curcount == 8)
            haveack = 1;
          else
            error = 1;

        else if (saved_pid[3:0] == NAK)
          if (curcount == 8)
            havenak = 1;
          else
            error =1;

        else if (saved_pid[3:0] == OUT || saved_pid[3:0] == IN) begin
          if (curcount == 24) begin
            havepkt = 1;
            pid = saved_pid[3:0];
            addr = pkt_out[15:9];
            endp = pkt_out[8:5];
          end
          else
            error = 1;
        end

        else if (saved_pid[3:0] == DATA0) begin
          if (curcount == 88) begin
            havepkt = 1;
            pid = saved_pid[3:0];
            data = pkt_out[80:16];
          end
          else
            error = 1;

        if (got_data) nextState = IDLE;
      end
    endcase

  end
endmodule: bitstream_encoder
