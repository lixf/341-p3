/** @file primitives.sv
 *  @brief Implements all kinds of crap
 *  @author Xiaofan Li
 **/


module register
#(parameter WIDTH = 32)
(input logic clk,rst_b,
 input logic [WIDTH-1:0] Q,
 input logic ld_reg,clr_reg,
 output logic [WIDTH-1:0] D);

  always_ff @(posedge clk,negedge rst_b) begin
    if(~rst_b)
      D <= 0;
    else if (clr_reg)
      D <= 0;
    else if (ld_reg)
      D <= Q;
  end
endmodule


module counter 
#(parameter WIDTH = 32)
(input logic clk,rst_b,
 input logic inc_cnt,clr_cnt,
 output logic [WIDTH-1:0] cnt);
  
  logic ld_reg, clr_reg;
  logic [WIDTH-1:0] in_reg,out_reg;

  register r_in_cnt(.Q(in_reg),.D(out_reg),.*);
  
  assign cnt = out_reg;

  always_comb begin
    clr_reg = 0;
    ld_reg = 0;
    if (clr_cnt) begin 
      clr_reg = 1;
    end
    else if (inc_cnt) begin
      in_reg = out_reg + 1;
      ld_reg = 1;
    end 
  end
endmodule


module shift_reg
#(parameter WIDTH = 32)
(input logic clk, rst_b,
 input logic inb, 
 input logic enable,
 output logic outb);

  logic[WIDTH-1:0] out_reg;

  //use generate to get a bunch of shift registers
  genvar i;
  generate 
    for (i=0;i<WIDTH;i++) begin: REGS
      if (i == 0)
        register R (.Q(inb),.D(out_reg[i+1]),.ld_reg(enable),.clr_reg(0),.*);
      else if (i == (WIDTH-1))
        register R (.Q(out_reg[i]),.D(outb),.ld_reg(enable),.clr_reg(0),.*);
      else 
        register R (.Q(out_reg[i]),.D(out_reg[i+1]),.ld_reg(enable),.clr_reg(0),.*);
    end
  endgenerate 

endmodule 



module test_shift;

  logic clk, rst_b, inb, outb, enable;
  
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
    $monitor($time," in: %b, out: %b, enable: %b, internal: %b",inb,outb,enable,dut.out_reg);
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


