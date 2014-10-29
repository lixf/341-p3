/** @file bit_stuff.sv
 *  @brief This implements the bit stuffer and bit unstuffer
 *  @author Xiaofan Li
 *  @author Chris Williamson
 **/


module bit_stuff
(input logic clk, rst_L,
 input logic inb,     // the input bit stream
 input logic start,   // the start of the packet is ignored
 output logic outb,   // the output stream
 output logic pause); // control signal to tell the upstream to pause

  // number of 1's seen so far
  logic[2:0] cnt;
  logic inc_cnt, clr_cnt;
  
  counter#(3) cnt_to_6(.rst_b(rst_L), .up(1'b1), .*);

  assign outb = pause ? 0 : inb;
  
  always_comb begin 
    pause = 0;
    clr_cnt = 0;
    inc_cnt = 0;

    if (start) begin 
      clr_cnt = 1;  
    end 
    else begin 
      if (cnt == 3'd6) begin 
        clr_cnt = 1;
        pause = 1;
      end 
      else begin 
        if (inb) 
          inc_cnt = 1;
        else 
          clr_cnt = 1;
      end
    end
  end
endmodule /* bit_stuff */

module bit_unstuff
(input logic clk, rst_L,
 input logic inb, recving,     // the input bit stream
 output logic sending, 
 output logic outb,   // the output stream
 output logic pause); // tell the bitstream decoder & CRC to wait a tick


  enum logic [1:0] {WAIT_SOP, SOP, SEND} state, nextState;

  always_ff @(posedge clk, negedge rst_L)
    if (~rst_L)
      state <= WAIT_SOP;
    else
      state <= nextState;

  /* SOP detection */
  logic [2:0] sopcnt;
  logic inc_sop, clr_sop;
  counter#(3) cnt_sop_0s(.inc_cnt(inc_sop), .clr_cnt(clr_sop),
                         .cnt(sopcnt), .rst_b(rst_L), .up(1'b1), .*);
  // number of 1's seen so far
  logic[2:0] cnt;
  logic inc_cnt, clr_cnt;
  counter#(3) cnt_to_6(.rst_b(rst_L), .up(1'b1), .*);
  // Wait until after PID to start stuffing
  logic[3:0] pidcount;
  logic inc_pid, clr_pid;
  counter#(4) cnt_pid(.cnt(pidcount),.inc_cnt(inc_pid),.clr_cnt(clr_pid),
                      .rst_b(rst_L), .up(1'b1), .*);

  assign outb = inb;
  
  always_comb begin 
    pause = 0;
    clr_cnt = 0;
    inc_cnt = 0;
    sending = 0;
    inc_sop = 0;
    clr_sop = 0;
    inc_pid = 0;
    clr_pid = 0;
    nextState = state;

    case (state)
      /*the bit unstuffer is the first module which sees the SOP byte, so it's
       * responsible for recognizing the SOP and sending out the "sending data"
       * signal to the rest of the pipeline. */
      WAIT_SOP: begin
        if (recving) begin
          if (~inb) begin
            inc_sop = 1;
            nextState = SOP;
          end 
          else
            clr_sop = 1;
            clr_pid = 1;
          //else wait for it
        end
      end

      SOP: begin 
        if (inb == 1 && sopcnt == 3'd6) begin
          inc_sop = 1;
          nextState = SEND;
        end
        else if (inb == 0 && sopcnt != 3'd6) begin
          nextState = SOP;
          inc_sop = 1;
        end
        else begin 
          //error
          clr_sop = 1;
          nextState = WAIT_SOP;
        end
      end

      SEND: begin
        if (~recving) begin
          nextState = WAIT_SOP;
          clr_cnt = 1;
        end 
        else begin 
          sending = 1;
          if (cnt == 3'd6) begin 
            clr_cnt = 1;
            pause = 1;
          end 
          else begin 
            if (pidcount == 4'd7) begin
              if (inb) 
                inc_cnt = 1;
              else 
                clr_cnt = 1;
            end
            else
              inc_pid = 1;
          end
        end
      end
    endcase

  end
endmodule /* bit_stuff */

/*
// testbench for the bit stuffer
module testbench;

  logic clk,rst_L,inb,outb,pause;

  bit_stuff dut(.*);

  initial begin 
    clk = 0;
    rst_L = 0;
    #2 rst_L <= 1;
    forever #5 clk = ~clk;
  end

  initial begin 
    $display($time," rst_L %b, inb %b, outb %b, pause %b",rst_L,inb,outb,pause);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b, pause %b",rst_L,inb,outb,pause);
    inb <= 1;
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b, pause %b",rst_L,inb,outb,pause);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b, pause %b",rst_L,inb,outb,pause);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b, pause %b",rst_L,inb,outb,pause);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b, pause %b",rst_L,inb,outb,pause);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b, pause %b",rst_L,inb,outb,pause);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b, pause %b",rst_L,inb,outb,pause);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b, pause %b",rst_L,inb,outb,pause);
    $finish;
  end
endmodule

*/
