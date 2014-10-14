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
