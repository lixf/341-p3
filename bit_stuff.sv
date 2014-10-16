/** @file bit_stuff.sv
 *  @brief This implements the bit stuffer in prelab
 *  @author Xiaofan Li
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

  //bits to ignore 
  logic [3:0] cnt16;
  logic inc_cnt16, clr_cnt16;
  
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
