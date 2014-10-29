/** @brief Controls logic to output to/from the USB thumb drive
 *
 *  @author Xiaofan Li
 *  @author Chris Williamson
 **/

module from_usb
(input logic clk, rst_L,
 input logic d_p, d_m,
 output logic outb, sending, eop);

  enum logic [1:0] {DECODE, EOP0, EOP1} state, nextState;

  always_ff @(posedge clk, negedge rst_L)
    if (~rst_L)
      state <= DECODE;
    else
      state <= nextState;

  always_comb begin
    eop = 0;
    sending = 0;
    outb = 0;
    nextState = DECODE;

    case (state)
      DECODE: begin
        sending = 1;
        if (d_p == 1 && d_m == 0)
          outb = 1;
        else if (d_p == 0 && d_m == 1)
          outb = 0;
        else if (d_p == 0 && d_m == 0) begin
          sending = 0;
          eop = 1;
          nextState = EOP0;
        end
      end
      EOP0: begin
        eop = 1;
        if (d_p == 0 && d_m == 0)
          nextState = EOP1;
      end
      EOP1: begin
        eop = 1;
        if (d_p == 1 && d_m == 0)
          nextState = DECODE;
      end
    endcase
  end

endmodule

module to_usb
(input logic clk, rst_L,
 input logic data_bit,data_start,data_end,
 output logic d_p, d_m, 
 output logic ready, sending);
  
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
    sending = 0;
    case (state)
      IDLE: begin 
        if (~data_start) begin 
          d_p = 1;
          next_state = IDLE;
          ready = 1;
        end 
        else begin
          sending = 1;
          if (data_bit)
            d_p = 1; // send J
          else 
            d_m = 1; // send K
          
          next_state = SEND;
        end
      end 
      
      SEND: begin 
        
        sending = 1;
        if (data_bit)begin
          d_p = 1; // send J
        end
        else begin  
          d_m = 1; // send K
        end
        if (data_end) begin
          next_state = END0;
        end 
        else begin
          next_state = SEND;
        end
      end 

      END0: begin 
        sending = 1;
        next_state = END1;
        //second SE0
      end 
      END1: begin 
        next_state = END2;
        sending = 1;
        //first SE0
      end 

      END2: begin 
        d_p = 1; // send J
        sending = 1;
        next_state = IDLE;
      end
    endcase 
  end
endmodule
