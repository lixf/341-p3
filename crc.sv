/** @file crc.sv
 *  @brief computes the CRC of the incoming bitstream, then attaches it to the
 *         end of the stream once we stop receiving bits.  
 *  @author Chris Williamson
 **/


module crc
(input logic clk, rst_L,
 input logic pause_out,
 input logic inb, recving,
 input logic start,
 output logic pause_in,
 output logic outb, sending);

  enum logic [1:0] {IDLE, CALCCRC, SENDCRC} state, nextState;
  
  logic [4:0] crc_save;
  //logic crc_outb, crc_done;
  logic crc5_x2_inb, crc5_x2_outb, crc5_x5_inb, crc5_x5_outb;
  logic shift_crc, init_crc;
  logic [3:0] curcount;
  logic clear_count, inc_count;

  crc_shiftreg #(2) crc5_x2(.Q({crc_save[0],crc_save[1]}), .inb(crc_x2_inb), 
                    .outb(crc_x2_outb),.shift(shift_crc), .clr(init_crc), 
                    .rst_b(rst_L), .*);

  crc_shiftreg #(3) crc5_x5(.Q({crc_save[2],crc_save[3],crc_save[4]}), .inb(crc_x5_inb), 
                    .outb(crc_x5_outb),.shift(shift_crc), .clr(init_crc), 
                    .rst_b(rst_L), .*);
  
  /*
  piso_shiftreg #(5) storedcrc(.D(crc_save), .ld_reg(crc_done), .clr_reg(1'b0), 
                    .en(state == SENDCRC), .outb(crc_outb), .rst_b(rst_L), .*);
  */
  counter #(4) outcrc_remaining(.inc_cnt(inc_count), .up(1'b1), .cnt(curcount), 
                                .clr_cnt(clear_count), .rst_b(rst_L), .*);

  assign crc_x2_inb = crc_x5_outb ^ inb;
  assign crc_x5_inb = crc_x2_inb ^ crc_x2_outb;

  always_ff @(posedge clk, negedge rst_L)
  if (~rst_L)
    state <= IDLE;
  else
    state <= nextState;

  always_comb begin
    shift_crc = 0;
    init_crc = 0;
    pause_in = 0;
    outb = 0;
    sending = 0;
    /* counter control */
    clear_count = 0;
    inc_count = 0;

    case (state)
      IDLE: begin
        outb = inb;
        if (recving & (~start)) begin
          shift_crc = 1;
          nextState = CALCCRC;
          sending = 1;
        end
        else begin 
          nextState = IDLE;
          init_crc = 1;
        end
      end
      CALCCRC: begin
        sending = 1;
        outb = inb;
        clear_count = 1;
        if (~pause_out)
          shift_crc = 1;
        if (~recving) begin
          shift_crc = 0;
          clear_count = 0;
          inc_count = 1;
          outb = ~crc_save[4 - curcount];
          nextState = SENDCRC;
        end
        else 
          nextState = CALCCRC;
      end
      SENDCRC: begin
        sending = 1;
        pause_in = 1;
        inc_count = 1;
        outb = ~crc_save[4 - curcount];
        if (curcount == 4)begin
          nextState = IDLE;
          init_crc = 1;
        end
        else 
          nextState = SENDCRC;
      end
    endcase

  end
endmodule: crc


/*
module testbench;

  logic clk, rst_L;
  logic pause_out,inb, recving;
  logic pause_in,outb, sending;

  crc dut(.*);

  initial begin 
    clk = 0;
    rst_L = 0;
    #2 rst_L <= 1;
    forever #5 clk = ~clk;
  end

  initial begin 
    $monitor($time," rst_L %b, inb %b, outb %b, pause_out %b state: %s",rst_L,inb,outb,pause_out,dut.state);
    @(posedge clk);
    inb <= 1;
    recving <= 1;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    recving <= 0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $finish;
  end
endmodule


*/
