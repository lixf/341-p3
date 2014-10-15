/** @file bitstream_enc.sv
 *  @brief The bitstream encoder for serial output
 *  @author Chris Williamson
 **/

`include "primitives.sv"

module bitstream_encoder
(input logic clk, rst_L,
 input logic pause, pktready,
 input logic [3:0] pid, [6:0] addr, [63:0] data, [3:0] endp,
 output logic outb, sending, gotpkt);

  enum logic {IDLE, LOAD, 
              SEND_PID, SEND_ADDR, SEND_DATA, SEND_ENDP} state, nextState;
  logic loadpkt;
  logic pid_outb, addr_outb, data_outb, endp_outb;
  logic shift_pid, shift_addr, shift_data, shift_endp;
  logic [7:0] curcount;

  enum logic [3:0] {OUT = 0'b0001, IN = 0'b1001, DATA0 = 0'b0011,
                    ACK = 0'b0010, NAK = 0'b1010} current_pid;

  /* Keep the PID packet around so we can remember which fields to send after
   * it's been shifted out (i.e. we need to know whether there's a valid data
   * packet after the PID field) */
  register #(4) saved_pid(.rst_b(rst_L), .D(pid), .Q(current_pid),
                          .ld_reg(loadpkt), .clr_reg(0), .*);

  piso_shiftreg #(8) pid_reg(.rst_b(rst_L), .D({~pid, pid}), .outb(pid_outb),
                             .ld_reg(loadpkt), .clr_reg(0), .en(shift_pid), .*);

  piso_shiftreg #(7) addr_reg(.rst_b(rst_L), .D(addr), .outb(addr_outb),
                             .ld_reg(loadpkt), .clr_reg(0), .en(shift_addr), .*);

  piso_shiftreg #(64) data_reg(.rst_b(rst_L), .D(data), .outb(data_outb),
                             .ld_reg(loadpkt), .clr_reg(0), .en(shift_data), .*);

  piso_shiftreg #(4) endp_reg(.rst_b(rst_L), .D(endp), .outb(endp_outb),
                             .ld_reg(loadpkt), .clr_reg(0), .en(shift_endp), .*);

  /* down-counter - set to number of bytes in each field when we start
   * reading the field out, then shift and read its outb until it hits 0, then
   * either stop or move onto the next field as necessary. */
  counter #(8) field_remaining(.inc_cnt(downcount), .clr_cnt(0), .up(0),
                               .cnt(curcount), .*);

  always_ff @(posedge clk, negedge rst_L)
  if (~rst_L)
    state <= IDLE;
  else
    state <= nextState;
    
  always_comb begin

    nextState = state;
    /* control for registers */
    loadpkt = 0;
    shift_pid = 0;
    shift_addr = 0;
    shift_data = 0;
    shift_endp = 0;
    /* protocol */
    outb = 0;
    sending = 0;
    gotpkt = 0;
    /* counter control */
    counter_init = 0;
    ldcounter = 0;
    downcount = 0;

    case (state):
      IDLE: begin
        if (pktready)
          nextState = LOAD;
      end
      LOAD: begin
        loadpkt = 1;
        gotpkt = 1;
        counter_init = 0'd8; // # pid bits
        ldcounter = 1;
        nextState = SEND_PID;
      end
      SEND_PID: begin
        sending = 1;
        outb = pid_outb;
        if (~pause) begin
          shift_pid = 1;
          downcount = 1;
        end
        if (curcount == 0) begin
          downcount = 0;
          ldcounter = 1;
          if (current_pid == ACK || current_pid == NAK) begin
            nextState = IDLE;
          end else if (current_pid == OUT || current_pid == IN) begin
            counter_init = 0'd7; // # addr bits
            nextState = SEND_ADDR;
          end else begin
            counter_init = 0'd64; // # data bits
            nextState = SEND_DATA;
          end
        end
      end
      SEND_ADDR: begin
        sending = 1;
        outb = addr_outb;
        if (~pause) begin
          shift_addr = 1;
          downcount = 1;
        end
        if (curcount == 0) begin
          counter_init = 0'd4 // # endp bits
          nextState = SEND_ENDP;
        end
      end
      SEND_ENDP: begin
        sending = 1;
        outb = endp_outb;
        if (~pause) begin
          shift_endp = 1;
          downcount = 1;
        end
        if (curcount == 0) begin
          nextState = IDLE;
        end
      end
      SEND_DATA: begin
        sending = 1;
        outb = data_outb;
        if (~pause) begin
          shift_data = 1;
          downcount = 1;
        end
        if (curcount == 0) begin
          nextState = IDLE;
        end
      end
    endcase

  end

endmodule: bitstream_encoder
