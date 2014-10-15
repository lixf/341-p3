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
  logic [3:0] current_pid;

  /* Keep the PID packet around so we can remember what to send after it's
   * been shifted out */
  register #(4) saved_pid(.rst_b(rst_L), .D(pid), .Q(current_pid),
                          .ld_reg(loadpkt), .clr_reg(0), .*)

  piso_register #(8) pid_reg(.rst_b(rst_L), .D({~pid, pid}), .outb(pid_outb),
                             .ld_reg(loadpkt), .clr_reg(0), .en(shift_pid)

  piso_register #(7) addr_reg(.rst_b(rst_L), .D(addr), .outb(addr_outb),
                             .ld_reg(loadpkt), .clr_reg(0), .en(shift_addr)

  piso_register #(64) data_reg(.rst_b(rst_L), .D(data), .outb(data_outb),
                             .ld_reg(loadpkt), .clr_reg(0), .en(shift_data)

  piso_register #(4) endp_reg(.rst_b(rst_L), .D(endp), .outb(endp_outb),
                             .ld_reg(loadpkt), .clr_reg(0), .en(shift_endp)

  /*
  counter #(8) field_remaining
  */

  always_ff @(posedge clk, negedge rst_L)
  if (~rst_L)
    state <= IDLE;
  else
    state <= nextState;
    
  /* TODO state transition, output selection, and shift reg control logic */

endmodule: bitstream_encoder
