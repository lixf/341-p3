/** @file primitives.sv
 *  @brief Implements all kinds of crap
 *  @author Xiaofan Li
 *  @author Chris Williamson
 **/


module register
#(parameter WIDTH = 32)
(input logic clk,rst_b,
 input logic [WIDTH-1:0] D,
 input logic ld_reg,clr_reg,
 output logic [WIDTH-1:0] Q);

  always_ff @(posedge clk,negedge rst_b) begin
    if(~rst_b)
      Q <= 0;
    else if (clr_reg)
      Q <= 0;
    else if (ld_reg)
      Q <= D;
  end
endmodule


module counter 
#(parameter WIDTH = 32)
(input logic clk,rst_b,
 input logic inc_cnt, clr_cnt, up,
 output logic [WIDTH-1:0] cnt);
  
  logic ld_reg, clr_reg;
  logic [WIDTH-1:0] in_reg,out_reg;

  register #(WIDTH) r_in_cnt(.D(in_reg),.Q(out_reg),.*);
  
  assign cnt = out_reg;

  always_comb begin
    clr_reg = 0;
    ld_reg = 0;
    if (clr_cnt) begin 
      clr_reg = 1;
    end
    else if (inc_cnt) begin
      if (up)
        in_reg = out_reg + 1;
      else
        in_reg = out_reg - 1;
      ld_reg = 1;
    end 
  end
endmodule


module piso_shiftreg
#(parameter WIDTH = 32)
(input logic clk, rst_b,
 input logic [WIDTH-1:0] D,
 input logic ld_reg, clr_reg, en,
 output logic outb);

  logic [WIDTH-1:0] Q, outreg_D;
  logic outreg_load;
  register #(WIDTH) out_reg(.D(outreg_D), .ld_reg(outreg_load), .*);

  assign outb = Q[0],
         outreg_load = 1;

  always_comb begin
    if (ld_reg)
      outreg_D = D;
    else if (~en)
      outreg_D = Q;
    else
      outreg_D = {1'b0, Q[WIDTH-1:1]};
  end

endmodule 


module crc_shiftreg
#(parameter WIDTH = 32)
(input logic clk, rst_b,
 input logic clr, // clr initializes the bits to 1
 input logic shift, inb,
 output logic outb, // the output bit
 output logic [WIDTH-1:0] Q); // the entire contents of the register

  always_ff @(posedge clk, negedge rst_b)
  if (~rst_b)
    Q <= 0;
  else if (clr)
    Q <= ~0;
  else if (shift)
    Q <= {inb, Q[WIDTH-1:1]};
  else
    Q <= Q;
  
  assign outb = Q[0];

endmodule
/*
module test_shift_piso;

  logic clk, rst_b, ld_reg, clr_reg, en, outb;
  logic[4:0] D;
  
  piso_shiftreg#(5) dut(.*);
  
  initial begin
    clk = 0;
    rst_b <= 0;
    #2 rst_b <= 1;
    forever #5 clk = ~clk;
  end
  
  //use clocking
  default clocking myDelay
    @(posedge clk);
  endclocking 

  initial begin
    $monitor($time," D: %b, internal:%b, out: %b, enable: %b, ld: %b, clr: %b",D,dut.Q,outb,en,ld_reg,clr_reg);
    D <= 5'b11111;
    en <=1;
    ld_reg <= 1;
    clr_reg <= 0;
    ##1;
    ld_reg <= 0;
    ##5;
    D <= 5'b01010;
    ld_reg <= 0;
    clr_reg <= 1;
    ##1;
    clr_reg <= 0;
    ##2;
    D <= 5'b11000;
    ld_reg <= 1;
    ##3;
    D <= 5'b11100;
    ##2;
    en <= 0;
    ##5;
    en <=1;
    ##5;
    $finish;
  end
endmodule 

module test_shift;

  logic clk, rst_b, inb, outb, enable;
  logic[4:0] out_full;
  
  shift_reg#(5) dut(.*);
  
  initial begin
    clk = 0;
    rst_b <= 0;
    #2 rst_b <= 1;
    forever #5 clk = ~clk;
  end
  
  //use clocking
  default clocking myDelay
    @(posedge clk);
  endclocking 

  initial begin
    $monitor($time," in: %b, out: %b, enable: %b, internal: %b",inb,outb,enable,out_full);
    inb <= 1;
    enable <=1;
    ##3;
    inb <=0;
    ##2;
    inb <= 1;
    ##3;
    inb <=0;
    ##2;
    enable <= 0;
    ##5;
    enable <=1;
    ##5;
    $finish;
  end
endmodule 

*/
