/** @file bitstream_enc.sv
 *  @brief The bitstream encoder for serial output
 *  @author Chris Williamson
 **/


module bitstream_encoder
(input logic clk, rst_L,
 input logic pause, pktready,
 input logic [3:0] pid, [6:0] addr, [63:0] data, [3:0] endp,
 output logic outb, sending, down_ready,
 output logic start, gotpkt);

  enum logic [2:0] {IDLE, SEND_SYNC, 
              SEND_PID, SEND_ADDR, SEND_DATA, SEND_ENDP} state, nextState;
  /* shift registers */
  logic loadpkt;
  logic pid_outb, addr_outb, data_outb, endp_outb;
  logic shift_pid, shift_addr, shift_data, shift_endp;
  logic syn_outb, shift_syn;
  /* counter */
  logic [7:0] curcount;
  logic count, clrcounter;

  enum logic [3:0] {OUT = 4'b0001, IN = 4'b1001, DATA0 = 4'b0011,
                    ACK = 4'b0010, NAK = 4'b1010} current_pid;

  /* Keep the PID packet around so we can remember which fields to send after
   * it's been shifted out (i.e. we need to know whether there's a valid data
   * packet after the PID field) */
  register #(4) saved_pid(.rst_b(rst_L), .D(pid), .Q(current_pid),
                          .ld_reg(loadpkt), .clr_reg(1'b0), .*);

  piso_shiftreg #(8) pid_reg(.rst_b(rst_L), .D({~pid, pid}), .outb(pid_outb),
                             .ld_reg(loadpkt), .clr_reg(1'b0), .en(shift_pid), .*);
  
  piso_shiftreg #(8) syn_reg(.rst_b(rst_L), .D(8'b1000_0000), .outb(syn_outb),
                             .ld_reg(loadpkt), .clr_reg(1'b0), .en(shift_syn), .*);

  piso_shiftreg #(7) addr_reg(.rst_b(rst_L), .D(addr), .outb(addr_outb),
                             .ld_reg(loadpkt), .clr_reg(1'b0), .en(shift_addr), .*);

  piso_shiftreg #(64) data_reg(.rst_b(rst_L), .D(data), .outb(data_outb),
                             .ld_reg(loadpkt), .clr_reg(1'b0), .en(shift_data), .*);

  piso_shiftreg #(4) endp_reg(.rst_b(rst_L), .D(endp), .outb(endp_outb),
                             .ld_reg(loadpkt), .clr_reg(1'b0), .en(shift_endp), .*);

  /* down-counter - set to number of bytes in each field when we start
   * reading the field out, then shift and read its outb until it hits 0, then
   * either stop or move onto the next field as necessary. */
  counter #(8) field_remaining(.inc_cnt(count), .clr_cnt(clrcounter), .up(1'b1),
                               .cnt(curcount),.rst_b(rst_L),.*);

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
    clrcounter = 0;
    count = 0;
    start = 0;
    down_ready = 0;

    case (state)
      IDLE: begin
        if (pktready)begin
          loadpkt = 1;
          gotpkt = 1;
          clrcounter = 1;
          nextState = SEND_SYNC;
          //nextState = LOAD;
        end
        else begin 
          down_ready = 1;
          nextState = IDLE;
        end
      end
      //LOAD: begin
      //  loadpkt = 1;
      //  gotpkt = 1;
      //  clrcounter = 1;
      //  nextState = SEND_SYNC;
      //end

      SEND_SYNC: begin
        sending = 1;
        start = 1;
        outb = syn_outb;
        nextState = SEND_SYNC;
        if (~pause) begin
          shift_syn = 1;
          count = 1;
        end
        if (curcount == 8'd7) begin
          count = 0;
          clrcounter = 1;
          nextState = SEND_PID;
        end
      end
        
      SEND_PID: begin
        sending = 1;
        start = 1;
        outb = pid_outb;
        nextState = SEND_PID;
        if (~pause) begin
          shift_pid = 1;
          count = 1;
        end
        if (curcount == 8'd7) begin
          count = 0;
          clrcounter = 1;
          if (current_pid == ACK || current_pid == NAK) begin
            nextState = IDLE;
          end else if (current_pid == OUT || current_pid == IN) begin
            nextState = SEND_ADDR;
          end else begin
            nextState = SEND_DATA;
          end
        end
      end
      SEND_ADDR: begin
        sending = 1;
        outb = addr_outb;
        nextState = SEND_ADDR;
        if (~pause) begin
          shift_addr = 1;
          count = 1;
        end
        if (curcount == 8'd6) begin
          clrcounter = 1;
          nextState = SEND_ENDP;
        end
      end
      SEND_ENDP: begin
        sending = 1;
        outb = endp_outb;
        nextState = SEND_ENDP;
        if (~pause) begin
          shift_endp = 1;
          count = 1;
        end
        if (curcount == 8'd3) begin
          clrcounter = 1;
          nextState = IDLE;
        end
      end
      SEND_DATA: begin
        sending = 1;
        outb = data_outb;
        nextState = SEND_DATA;
        if (~pause) begin
          shift_data = 1;
          count = 1;
        end
        if (curcount == 8'd63) begin
          clrcounter = 1;
          down_ready = 1;
          nextState = IDLE;
        end
      end
    endcase

  end
endmodule: bitstream_encoder


/*
module test_bitstream;
  logic clk, rst_L, pause, pktready;
  logic outb, sending, gotpkt;
  logic[3:0] pid, endp;
  logic[6:0] addr;
  logic[63:0] data;

  
  bitstream_encoder dut(.*);
  
  initial begin
    clk = 0;
    rst_L <= 0;
    #2 rst_L <= 1;
    forever #5 clk = ~clk;
  end
  
  //use clocking
  default clocking myDelay
    @(posedge clk);
  endclocking 

  initial begin
    $monitor($time," pid: %b addr: %b outb: %b sending: %b gotpkt %b state: %s",pid,addr,outb,sending,gotpkt,dut.state);
    pid <= 4'b0001;
    addr <= 7'b1101101;
    endp <= 4'b1101;
    pause <= 0;
    pktready <= 1;
    ##5;
    pid <= 4'b1001;
    addr <= 7'b0101101;
    endp <= 4'b1001;
    pktready <= 1;
    ##5;
    pid <= 4'b0001;
    addr <= 7'b1111101;
    endp <= 4'b1100;
    pktready <= 1;
    ##5;
    ##5;
    ##5;
    ##5;
    $finish;
  end
endmodule 
*/
