/** @file crc.sv
 *  @brief computes the CRC of the incoming bitstream, then attaches it to the
 *         end of the stream once we stop receiving bits.  
 *  @author Chris Williamson
 **/


module crc_encode
(input logic clk, rst_L,
 input logic pause_out,
 input logic inb, recving, pkttype, // pkttype = 1 for 16-bit crc, 0 for 5-bit
 input logic start,
 output logic pause_in,
 output logic outb, sending);

  enum logic [1:0] {IDLE, CALCCRC, SENDCRC} state, nextState;

  logic crc_type;
  
  logic [4:0] crc5_result;
  logic [15:0] crc16_result;
  logic crc5_x2_inb, crc5_x2_outb, crc5_x5_inb, crc5_x5_outb;

  logic crc16_x2_inb, crc16_x2_outb;
  logic crc16_x15_inb, crc16_x15_outb;
  logic crc16_x16_inb, crc16_x16_outb;

  logic shift_crc, init_crc;
  logic [4:0] curcount;
  logic clear_count, inc_count;

  /* 5-bit CRC */
  crc_shiftreg #(2) crc5_x2(.Q(crc5_result[1:0]), .inb(crc5_x2_inb), 
                    .outb(crc5_x2_outb),.shift(shift_crc), .clr(init_crc), 
                    .rst_b(rst_L), .*);

  crc_shiftreg #(3) crc5_x5(.Q(crc5_result[4:2]), .inb(crc5_x5_inb), 
                    .outb(crc5_x5_outb),.shift(shift_crc), .clr(init_crc), 
                    .rst_b(rst_L), .*);
  
  /* 16-bit CRC */
  crc_shiftreg #(2) crc16_x2(.Q(crc16_result[1:0]), .inb(crc16_x2_inb), 
                    .outb(crc16_x2_outb),.shift(shift_crc), .clr(init_crc), 
                    .rst_b(rst_L), .*);

  crc_shiftreg #(13) crc16_x15(.Q(crc16_result[14:2]), .inb(crc16_x15_inb), 
                    .outb(crc15_x2_outb),.shift(shift_crc), .clr(init_crc), 
                    .rst_b(rst_L), .*);

  crc_shiftreg #(1) crc16_x16(.Q(crc16_result[15]), .inb(crc16_x16_inb), 
                    .outb(crc16_x16_outb),.shift(shift_crc), .clr(init_crc), 
                    .rst_b(rst_L), .*);
  
  counter #(5) outcrc_remaining(.inc_cnt(inc_count), .up(1'b1), .cnt(curcount), 
                                .clr_cnt(clear_count), .rst_b(rst_L), .*);

  assign crc5_x2_inb = crc5_x5_outb ^ inb;
  assign crc5_x5_inb = crc5_x2_inb ^ crc5_x2_outb;

  assign crc16_x2_inb = crc16_x16_outb ^ inb;
  assign crc16_x15_inb = crc16_x2_inb ^ crc16_x2_outb;
  assign crc16_x16_inb = crc16_x2_inb ^ crc16_x15_outb;

  always_ff @(posedge clk, negedge rst_L)
  if (~rst_L)
    state <= IDLE;
  else begin
    if (recving) crctype <= pkttype; // Remember pkt type after done receiving
    state <= nextState;
  end

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
          inc_count = 0;
          if (crctype == 1'b0) begin
            outb = ~crc5_result[4 - curcount];
            nextState = SENDCRC5;
          end
          else begin
            outb = ~crc5_result[15 - curcount];
            nextState = SENDCRC16;
          end
        else
          nextState = CALCCRC;
      end
      SENDCRC5: begin
        sending = 1;
        pause_in = 1;
        inc_count = 1;
        outb = ~crc5_result[4 - curcount];
        if (curcount == 4)begin
          nextState = IDLE;
          init_crc = 1;
        end
        else 
          nextState = SENDCRC5;
      end
      SENDCRC16: begin
        sending = 1;
        pause_in = 1;
        inc_count = 1;
        outb = ~crc5_result[15 - curcount];
        if (curcount == 15)begin
          nextState = IDLE;
          init_crc = 1;
        end
        else 
          nextState = SENDCRC16;
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
