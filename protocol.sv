/** @file protocol.sv
 *  @brief This file implements the protocol FSM in USB lab 18341 f14
 *
 *  <DESCRIPTION HERE>
 *  
 *  @author Xiaofan Li
 *  @bug Nope
 */

//`include "pipeline.sv"
//`include "primitives.sv"

//module tester;
// logic clk, rst_L;
// logic send_in;          // from R/W FSM to send a IN 
// logic input_ready;      // control signal from R/W FSM
// logic [63:0] data;      // stuff to send out
// logic [6:0] addr; 
// logic [3:0] endp;    
// 
// logic down_input;       // control signal from down stream: things here
// logic down_ready;       // if the downstream is ready to receive
// logic corrupted;        // asserted if the data is corrupted
// logic ack;              // received a ack
// logic nak;             // received a nak
// logic [63:0] data_in;   // data received
//
// logic free;            // to R/W FSM
// logic cancel;          // cancel this transaction
// logic recv_ready;      // data received and ready to be read
// logic [63:0] data_recv;// the data received 
// 
// logic pktready;        // to downstream senders
// logic [3:0] pid_out; 
// logic [6:0] addr_out; 
// logic [63:0] data_out; 
// logic [3:0] endp_out;
//
//  //use clocking
//  default clocking myDelay
//    @(posedge clk);
//  endclocking 
//
//  initial begin
//    clk = 0;
//    rst_L <= 0; //reset
//    forever #5 clk <= ~clk; 
//  end
//
//  //decalre some properties here!
//  
//
//  ProtocolFSM link(.*);
//  
//  initial begin
//    $monitor(" to R/W  (free: %b, cancel: %b, data_recv: %h)\n to down (pktready: %b, pid_out: %b, addr_out: %b, data_out: %h, endp_out: %b\n states: out: %s, in:%s rst_L: %b\n", 
//              free, cancel, data_recv, pktready, pid_out, addr_out, data_out, endp_out, link.zelda.state, link.hilda.state,link.rst_L);
//    ##1;
//    $display("init! test start in next clk cycle");
//    rst_L <= 1;
//    ##1;
//    $display("start testing OUT packet");
//    send_in <= 0;
//    data <= 64'haabbccdd; // data sending
//    addr <= 7'b0000111;   // whatever
//    endp <= 4'b0011;      // lol 
//    input_ready <= 1;
//
//    //emulate the downstream too 
//    down_ready <= 1;
//    
//    ##1;
//    //deassert some stuff
//    input_ready <= 0;
//    
//    //wait for a long time
//    ##10;
//    //send ack
//    ack <= 1;
//    
//    ##10;
//    $finish;
//  end
//
//endmodule


module ProtocolFSM
 //from R/W FSM
(input logic clk, rst_L,
 input logic send_in,          // from R/W FSM to send a IN 
 input logic input_ready,      // control signal from R/W FSM
 input logic sending_usb,
 input logic got_result,
 input logic [63:0] data,      // stuff to send out
 input logic [6:0] addr, 
 input logic [3:0] endp,    
 
 //from downstream
 input logic inpipe_recving,   // Input pipeline is currently receiving input
 input logic down_input,       // control signal from down stream: things here
 input logic down_ready,       // if the downstream is ready to receive
 input logic corrupted,        // asserted if the data is corrupted
 input logic ack,              // received a ack
 input logic nak,             // received a nak
 input logic [63:0] data_in,   // data received

 //to R/W FSM
 output logic free,            // to R/W FSM
 output logic cancel,          // cancel this transaction
 output logic recv_ready,      // data received and ready to be read
 output logic writing,
 output logic [63:0] data_recv,// the data received 
 
 //to downstream
 output logic pktready,        // to downstream senders
 output logic pkttype,
 output logic [3:0] pid_out, 
 output logic [6:0] addr_out, 
 output logic [63:0] data_out, 
 output logic [3:0] endp_out);

  
  logic in_ready, out_ready; // sending in or out?
  logic in_free, out_free;
  logic in_cancel, out_cancel;
  logic in_pktready, out_pktready;
  logic pkttype_in, pkttype_out;
  logic writing_out, writing_in;

  //data outputs need to be mux-ed
  logic [3:0] pid_out_in,pid_out_out; 
  logic [6:0] addr_out_in,addr_out_out; 
  logic [63:0] data_out_in,data_out_out; 
  logic [3:0] endp_out_in, endp_out_out;
 
  //choose mode with comb logic
  //big MUX
  always_comb begin
    in_ready  = 0;
    out_ready = 0;
    free      = 0;
    cancel    = 0;
    pktready  = 0;

    if (send_in) begin
      in_ready = input_ready;
      free     = in_free;
      cancel   = in_cancel;
      pktready = in_pktready;
      pid_out  = pid_out_in;
      data_out = data_out_in;
      addr_out = addr_out_in;
      endp_out = endp_out_in;
      pkttype  = pkttype_in;
      writing = writing_in;
    end 

    else begin 
      out_ready = input_ready;
      free      = out_free;
      cancel    = out_cancel;
      pktready  = out_pktready;
      pid_out   = pid_out_out;
      data_out  = data_out_out;
      addr_out  = addr_out_out;
      endp_out  = endp_out_out;
      pkttype   = pkttype_out;
      writing = writing_out;
    end 
  end


  //instantiation here
  outPktFSM zelda(.send_out(out_ready),.free(out_free),.cancel(out_cancel),
                  .pktready(out_pktready),.pid_out(pid_out_out),
                  .addr_out(addr_out_out),.data_out(data_out_out),
                  .endp_out(endp_out_out),.*);
  inPktFSM hilda (.send_in(in_ready),.free(in_free),.cancel(in_cancel),
                  .pktready(in_pktready),.pid_out(pid_out_in),
                  .addr_out(addr_out_in),.endp_out(endp_out_in),.*);
  
  // NOTE on ack/nak: system will be lock step when it waits for ack/nak
  // so it doesn't need to know about if i'm ready to see an ACK/NACK because 
  // I'll always be ready when you send ACK/NACK

endmodule




// get stuff from upstream and forward it down
module outPktFSM 
(input logic clk, rst_L,
 input logic send_out,         // R/W FSM wants to send a OUT
 input logic ack, nak,        // ack and nak signals
 input logic down_ready,       // if the downstream is ready to receive
 input logic sending_usb,
 input logic [63:0] data,      // data to send
 input logic [6:0] addr, 
 input logic [3:0] endp,
 
 output logic free,            // to R/W FSM
 output logic writing_out,     // if we are writing
 output logic cancel,          // cancel this transaction
 output logic pktready,        // to downstream senders
 output logic pkttype_out,
 output logic [3:0] pid_out, 
 output logic [6:0] addr_out, 
 output logic [63:0] data_out, 
 output logic [3:0] endp_out);
  
  enum logic [2:0] {WAIT,S_HEAD,SEND,S_DATA,WAIT_ACK,TIMEOUT} state,next_state;  
  
  logic ld_reg,clr_reg;
  logic [63:0] data_save;
  //use a register for capturing the data
  register #(64) out_data(.D(data),.Q(data_save),.rst_b(rst_L),.*);

  //lots of counters for protocol
  logic inc_time, clr_time, inc_timeout, clr_timeout;
  logic [7:0] cur_time;
  logic [3:0] timeout;
  logic up = 1'b1; /* counters count up */
  counter #(8) out_timer(.inc_cnt(inc_time), .clr_cnt(clr_time),
                          .cnt(cur_time),.rst_b(rst_L),.*);
  counter #(4) out_timeout(.inc_cnt(inc_timeout), .clr_cnt(clr_timeout),
                           .cnt(timeout),.rst_b(rst_L),.*);

  //implement the FSM
  always_ff @(posedge clk, negedge rst_L) begin
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
    pid_out   = 0;
    addr_out  = 0;
    data_out  = 0;
    endp_out  = 0;
    cancel    = 0;
    pkttype_out = 0;
    writing_out = 0;

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
        
        if (send_out) begin
          ld_reg = 1; /* capture the data */ 
          //the downstream must be ready here, so send
          pid_out  = 4'b0001;
          addr_out = addr;
          endp_out = endp;
          pktready = 1;
          writing_out = 1;
          next_state = S_HEAD;
        end
        else begin
          free = 1;
          next_state = WAIT;
        end
      
      end

      S_HEAD: begin 
        
        if ((~sending_usb) & down_ready) begin
          //send the DATA0 packet --> prevent deadlock
          next_state = SEND;
        end
        else begin
          //block if downstream is not ready
          next_state = S_HEAD;
        end 

      end 
      
      SEND: begin 
          pid_out  = 4'b0011;
          addr_out = addr;
          endp_out = endp;
          data_out = data_save;
          pkttype_out = 1;
          pktready = 1;
          writing_out = 1;
          clr_time = 1;
          next_state = S_DATA; 
      end

      S_DATA: begin 
        
        if (ack) begin 
          if (send_out) begin
            ld_reg = 1; /* capture the data */ 
            //the downstream must be ready here, so send
            pid_out  = 4'b0001;
            addr_out = addr;
            endp_out = endp;
            pktready = 1;
            writing_out = 1;
            next_state = S_HEAD;
          end
          else begin
            free = 1;
            next_state = WAIT; 
          end
        end 
        else if (nak) begin
          //resend the data packet
          pid_out  = 4'b0011;
          addr_out = addr;
          endp_out = endp;
          data_out = data_save;
          pktready = 1;
          pkttype_out = 1;
          writing_out = 1;
          next_state = S_DATA; 
        end 
        else begin
          //timeout after 20 clock cycle
          if (cur_time == 8'd255) begin 
            inc_timeout = 1;
            next_state = TIMEOUT;
          end 
          else begin
            inc_time = 1;
            pkttype_out = 1;
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
          pid_out  = 4'b0011;
          addr_out = addr;
          endp_out = endp;
          data_out = data_save;
          pktready = 1;
          pkttype_out = 1;
          writing_out = 1;
          next_state = S_DATA; 
        end

      end

    endcase
  end

endmodule 



module inPktFSM
(input logic clk, rst_L,
 input logic send_in,          // from R/W FSM to send a IN 
 input logic [6:0] addr, 
 input logic [3:0] endp,    
 input logic down_input,       // control signal from down stream: things here
 input logic down_ready,       // if the downstream is ready to receive
 input logic got_result,
 input logic inpipe_recving,
 input logic corrupted,        // asserted if the data is corrupted
 input logic [63:0] data_in,   // the data received from downstream
 
 output logic free,            // to R/W FSM
 output logic writing_in,
 output logic cancel,          // cancel this transaction
 output logic recv_ready,      // data ready to be read
 output logic [63:0] data_recv,// the data received 
 output logic pktready,        // to downstream senders
 output logic pkttype_in,
 output logic [3:0] pid_out, 
 output logic [6:0] addr_out, 
 output logic [3:0] endp_out);
  
  enum logic [2:0] {WAIT,W_DATA,HOLD,TIMEOUT} state,next_state;  
  
  //lots of counters for protocol
  logic inc_time, clr_time, inc_timeout, clr_timeout;
  logic inc_hold, clr_hold, clr_result;
  logic [7:0] cur_time;
  logic [4:0] timeout,cnt_hold;
  logic up = 1'b1; /* counters count up */
  counter #(8) out_timer(.inc_cnt(inc_time), .clr_cnt(clr_time),
                          .cnt(cur_time),.rst_b(rst_L),.*);
  counter #(5) out_timeout(.inc_cnt(inc_timeout), .clr_cnt(clr_timeout),
                           .cnt(timeout),.rst_b(rst_L),.*);
  counter #(5) out_wait(.inc_cnt(inc_hold), .clr_cnt(clr_hold),
                           .cnt(cnt_hold),.rst_b(rst_L),.*);
  register #(64) result(.D(data_in),.Q(data_recv),.ld_reg(down_input),
                        .clr_reg(clr_result | got_result),.rst_b(rst_L),.*);

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
    free       = 0;
    pktready   = 0;
    pid_out    = 0;
    addr_out   = 0;
    endp_out   = 0;
    cancel     = 0;
    recv_ready = 0;
    pkttype_in = 0;
    writing_in = 0;
    inc_hold   = 0;
    clr_hold   = 0;
    clr_result = 0;

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
          pid_out  = 4'b1001;
          addr_out = addr;
          endp_out = endp;
          writing_in = 1;
          pktready = 1;
          clr_result =1;
          clr_hold = 1;
          clr_time = 1;
          next_state = W_DATA;
        end
        else begin
          free = 1;
          next_state = WAIT;
        end
      
      end

      W_DATA: begin 
        if (inpipe_recving)
          next_state = W_DATA;
        else
        if (corrupted) begin 
          //send a NACK
          pid_out  = 4'b1010;
          pktready = 1;
          writing_in = 1;
          next_state = TIMEOUT;
        end
        else if (down_input) begin
          //data is here capture
          //send ack
          pid_out  = 4'b0010;
          pktready = 1;
          //signal the upstream 
          recv_ready = 1;
          writing_in = 1;
          next_state = HOLD;
        end
        //packet did not come
        else begin
          if (cur_time == 8'd255) begin
            next_state  = TIMEOUT;
          end 
          else begin 
            inc_time   = 1;
            next_state = W_DATA;
          end
        end 

      end 

      HOLD: begin
        if (cnt_hold == 5'd31) begin 
          next_state = WAIT;
        end
        else begin
          inc_hold = 1;
          recv_ready = 1;
          next_state = HOLD;
        end
      end


      TIMEOUT: begin
        
        if (timeout == 4'd7) begin
          //cancel the transaction
          clr_time = 1;
          clr_timeout = 1;
          cancel = 1;
          free = 1;
          next_state = WAIT;
        end 
        else begin 
          clr_time = 1;
          inc_timeout = 1;
          //send a NACK
          pid_out = 4'b1010;
          pktready = 1;
          writing_in = 1;
          next_state = W_DATA;
        end

      end

    endcase
  end

endmodule

