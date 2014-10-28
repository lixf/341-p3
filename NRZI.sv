/** @file NRZI.sv
 *  @brief NRZI encoding/decoding.
 *  @author Xiaofan Li
 *  @author Chris Williamson
 **/


module nrzi
(input logic clk, rst_L,
 input logic inb,     // the input bit stream
 output logic outb);  // the output stream
  
  logic D,Q,ld_reg,clr_reg;

  register#(1) reg_need_inv(.rst_b(rst_L),.*);
  
  //assuming the beginning is 1
  assign outb = ~D;

  always_comb begin
    ld_reg = 0;
    clr_reg = 0;
    //flip if input is 0
    if(~inb) begin 
      D = ~Q;
      ld_reg = 1;
    end
  end
endmodule /* bit_stuff */

module nrzi_decode
(input logic clk, rst_L,
 input logic inb,
 output logic outb);

  logic Q,ld_reg,clr_reg;

  register#(1) last_bit(.D(inb), .ld_reg(1'b1), .clr_reg(1'b0),
                        .rst_b(rst_L), .*);
  /* Output a 1 when the input stays the same, and 0 when it flips. */
  assign outb = (Q == inb);

endmodule

/*
// testbench for NRZI
module testbench;

  logic clk,rst_L,inb,outb;

  nrzi dut(.*);

  initial begin 
    clk = 0;
    rst_L = 0;
    #2 rst_L <= 1;
    forever #5 clk = ~clk;
  end

  initial begin 
    $display($time," rst_L %b, inb %b, outb %b",rst_L,inb,outb);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b",rst_L,inb,outb);
    inb <= 1;
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b",rst_L,inb,outb);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b",rst_L,inb,outb);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b",rst_L,inb,outb);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b",rst_L,inb,outb);
    inb <= 0;
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b",rst_L,inb,outb);
    inb <= 0;
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b",rst_L,inb,outb);
    @(posedge clk);
    $display($time," rst_L %b, inb %b, outb %b",rst_L,inb,outb);
    $finish;
  end
endmodule

*/
