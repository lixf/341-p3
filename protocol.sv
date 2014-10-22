/** @file protocol.sv
 *  @brief This file implements the protocol FSM in USB lab 18341 f14
 *
 *  <DESCRIPTION HERE>
 *  
 *  @author Xiaofan Li
 *  @bug Nope
 */

`include "primitives.sv"

module ProtocolFSM;
  logic clk,rst_L;
  //use clocking
  default clocking myDelay
    @(posedge clk);
  endclocking 
endmodule


// get stuff from upstream and forward it down
module outPktFSM 
(input logic clk, rst_L,
 input logic input_ready,      // control signal from R/W FSM
 input logic [63:0] data,      // data to send
 input logic ack, nack,        // ack and nack signals
 input logic down_ready,       // if the downstream is ready to receive
 input logic [6:0] addr_in, 
 input logic [3:0] endp_in,
 output logic free,            // to R/W FSM
 output logic cancel,          // cancel this transaction
 output logic pktready,        // to downstream senders
 output logic [3:0] pid, 
 output logic [6:0] addr, 
 output logic [63:0] data_out, 
 output logic [3:0] endp);
  
  enum logic [2:0] {WAIT,S_HEAD,S_DATA,WAIT_ACK,TIMEOUT} state,next_state;  
  
  logic ld_reg,clr_reg;
  logic [63:0] data_save;
  //use a register for capturing the data
  register #(64) out_data(.D(data),.Q(data_save),.rst_b(rst_L),.*);

  //lots of counters for protocol
  logic inc_time, clr_time, inc_timeout, clr_timeout;
  logic [19:0] cur_time;
  logic [3:0] timeout;
  logic up = 1'b1; /* counters count up */
  counter #(20) out_timer(.inc_cnt(inc_time), .clr_cnt(clr_time),
                          .cnt(cur_time),.rst_b(rst_L),.*);
  counter #(4) out_timeout(.inc_cnt(inc_timeout), .clr_cnt(clr_timeout),
                           .cnt(timeout),.rst_b(rst_L),.*);

  //implement the FSM
  always_ff @(posedge clk) begin
    if (~rst_L) 
      state <= WAIT;
    else 
      state <= next_state;
  end

  //next state logic
  always_comb begin
    //init values -- output
    free      = 0;
    pktready  = 0;
    pid       = 0;
    addr      = 0;
    data_out  = 0;
    endp      = 0;
    cancel    = 0;

    //init -- internal control signals
    clr_reg     = 0;
    ld_reg      = 0;
    inc_time    = 0;
    inc_timeout = 0;
    clr_time    = 0;
    clr_timeout = 0;

    //state transition
    case (state) 
      WAIT: begin 
        
        if (input_ready) begin
          ld_reg = 1; /* capture the data */ 
          //the downstream must be ready here, so send
          pid = 4'b0001;
          addr = addr_in;
          endp = endp_in;
          pktready = 1;
          next_state = S_HEAD;
        end
        else begin
          free = 1;
          next_state = WAIT;
        end
      
      end

      S_HEAD: begin 
        
        if (down_ready) begin
          //send the DATA0 packet
          pid = 4'b0011;
          addr = addr_in;
          endp = endp_in;
          data_out = data_save;
          pktready = 1;
          next_state = S_DATA; 
        end
        else begin
          //block if downstream is not ready
          next_state = S_HEAD;
        end 

      end 

      S_DATA: begin 
        
        //assume the decoding of ACK/NACK does not happen here
        if (ack) begin 
          free = 1;
          next_state = WAIT; 
        end 
        else if (nack) begin
          //resend the data packet
          pid = 4'b0011;
          addr = addr_in;
          endp = endp_in;
          data_out = data_save;
          pktready = 1;
          next_state = S_DATA; 
        end 
        else begin
          //timeout after 20 clock cycle
          if (cur_time == 8'd20) begin 
            inc_timeout = 1;
            next_state = TIMEOUT;
          end 
          else begin
            inc_time = 1;
            next_state = S_DATA;
          end 
        end 
      
      end

      TIMEOUT: begin
        
        if (timeout == 4'd8) begin
          //cancel the transaction
          clr_time = 1;
          clr_timeout = 1;
          clr_reg = 1;
          cancel = 1;
        end 
        else begin 
          clr_time = 1;
          inc_timeout = 1;
          //resend the data packet
          pid = 4'b0011;
          addr = addr_in;
          endp = endp_in;
          data_out = data_save;
          pktready = 1;
          next_state = S_DATA; 
        end

      end

    endcase
  end

endmodule 



module inPktFSM
(input logic clk, rst_L,
 input logic send_in,          // from R/W FSM to send a IN 
 input logic down_input,       // control signal from down stream: things here
 input logic [63:0] data,      // data received
 input logic down_ready,       // if the downstream is ready to receive
 input logic corrupted,        // asserted if the data is corrupted
 input logic [6:0] addr_in, 
 input logic [3:0] endp_in,    
 output logic free,            // to R/W FSM
 output logic cancel,          // cancel this transaction
 output logic pktready,        // to downstream senders
 output logic [63:0] data_recv,// the data received 
 output logic up_ready,        // signal the upstream that i'm ready
 output logic [3:0] pid, 
 output logic [6:0] addr, 
 output logic [3:0] endp,
 output logic [63:0] data_in); 
  
  enum logic [2:0] {WAIT,W_DATA,TIMEOUT} state,next_state;  
  
  //lots of counters for protocol
  logic inc_time, clr_time, inc_timeout, clr_timeout;
  logic [19:0] cur_time;
  logic [3:0] timeout;
  logic up = 1'b1; /* counters count up */
  counter #(20) out_timer(.inc_cnt(inc_time), .clr_cnt(clr_time),
                          .cnt(cur_time),.rst_b(rst_L),.*);
  counter #(4) out_timeout(.inc_cnt(inc_timeout), .clr_cnt(clr_timeout),
                           .cnt(timeout),.rst_b(rst_L),.*);

  //implement the FSM
  always_ff @(posedge clk) begin
    if (~rst_L) 
      state <= WAIT;
    else 
      state <= next_state;
  end

  //next state logic
  always_comb begin
    //init values -- output
    free      = 0;
    pktready  = 0;
    pid       = 0;
    addr      = 0;
    data_in   = 0;
    endp      = 0;
    cancel    = 0;
    up_ready  = 0;
    data_recv = 0;

    //init -- internal control signals
    inc_time    = 0;
    inc_timeout = 0;
    clr_time    = 0;
    clr_timeout = 0;

    //state transition
    case (state) 
      WAIT: begin 
        
        if (send_in) begin
          //the downstream must be ready here, so send
          pid = 4'b1001;
          addr = addr_in;
          endp = endp_in;
          pktready = 1;
          next_state = W_DATA;
        end
        else begin
          free = 1;
          next_state = WAIT;
        end
      
      end

      W_DATA: begin 
        
        if (down_input) begin
          //data is here capture
          if (corrupted) begin 
            //send a NACK
            pid = 4'b1010;
            pktready = 1;
            next_state = W_DATA;
          end
          else begin
            //send ack
            pid = 4'b0010;
            pktready = 1;
            //signal the upstream 
            data_recv = data;
            up_ready = 1;
            next_state = WAIT;
          end
        end
        //packet did not come
        else begin
          if (cur_time == 20'd20) begin
            inc_timeout = 1;
            next_state = TIMEOUT;
          end 
          else begin 
            inc_time = 1;
            next_state = W_DATA;
          end
        end 

      end 

      TIMEOUT: begin
        
        if (timeout == 4'd8) begin
          //cancel the transaction
          clr_time = 1;
          clr_timeout = 1;
          cancel = 1;
        end 
        else begin 
          clr_time = 1;
          inc_timeout = 1;
          //send a NACK
          pid = 4'b1010;
          pktready = 1;
          next_state = W_DATA;
        end

      end

    endcase
  end

endmodule



module ackFSM;

endmodule
