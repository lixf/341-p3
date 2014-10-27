/** @brief Controls logic to output to/from the USB thumb drive
 *
 *  @author Xiaofan Li
 *  @author Chris Williamson
 **/

module to_usb_top
(input logic clk, rst_L,
 input logic data_out_bit, data_out_start, data_out_end,
 output logic data_in_bit, data_in_sending, data_in_end,
 output logic d_p, d_m, out_ready);

  to_usb usboutput(.data_bit(data_out_bit), .data_start(data_out_start),
                   .data_end(data_out_end), .d_p(out_d_p), .d_m(out_d_m),
                   .*);

  /* TODO do tri-state driving, sending all input up to the bit-unstuffer
   * unless we're currently sending output. */

endmodule

module to_usb
(input logic clk, rst_L,
 input logic data_bit,data_start,data_end,
 output logic d_p, d_m, ready);
  
  enum logic [2:0] {IDLE,SEND,END0,END1,END2} state, next_state;

  always_ff @(posedge clk, negedge rst_L) begin 
    if (~rst_L)
      state <= IDLE;
    else 
      state <= next_state;
  end 

  always_comb begin 
    d_p = 0;
    d_m = 0;
    ready = 0;
    case (state)
      IDLE: begin 
        if (~data_start) begin 
          next_state = IDLE;
          ready = 1;
        end 
        else begin
          next_state = SEND;
          //send the SOP
          //d_m = 1;
        end
      end 
      
      SEND: begin 
        if (data_bit)
          d_p = 1; // send J
        else 
          d_m = 1; // send K
        
        if (data_end) begin 
          next_state = END0;
        end 
        else begin 
          next_state = SEND;
        end 
      end 

      END0: begin 
        next_state = END1;
        //first SE0
      end 
      END1: begin 
        next_state = END2;
        //second SE0
      end 

      END2: begin 
        next_state = IDLE;
        d_p = 1;
      end
    endcase 
  end
endmodule
