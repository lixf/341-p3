/** @brief This implements the read/write FSM
 *  
 *  @author Xiaofan Li
 *  @bug Unimplemented
 **/


//requires read/write signal to be asserted until it's done!!!

module ReadWrite
(input logic clk, rst_L,
 
 //from the read/write task
 input logic read,            // asserted when read
 input logic tran_ready,      // transaction is ready
 input logic [15:0] mempage,  // the address used for read/write
 input logic [63:0] data_in,  // data to write from R/W FSM

 //from protocol FSM
 input logic free,            // if the protocol FSM is able to send
 input logic bad,             // need to cancel the transaction

 //to protocol FSM
 output logic send_in,        // send an IN transaction
 output logic input_ready,    // Protocol FSM has valid input from us
 output logic [6:0] addr,
 output logic [3:0] endp,

 //to read/write task
 inout logic [63:0] data,      // the data to write out or read in
 output logic recv_ready,      // the received packet is ready 
 output logic done,            // the transaction is done 
 output logic cancel);         // if we failed forwarded from protocol

  enum logic [2:0] {WAIT,OUT,IN,DATA} state, next_state;

  //declare variable and modules here 
  logic [63:0] data_out;
  logic write;

  always_ff @(posedge clk) begin 
    if (~rst_L) begin
      state <= WAIT;
    end begin
      state <= next_state;
    end 
  end

  //deal with inout data
  assign data = write ? data_out : 'bz;

  //state transition
  always_comb begin
    send_in = 0;
    input_read = 0;
    addr = 0;
    endp = 0;
    recv_ready = 0;
    cancel = 0;
    done = 0;
    data_out = 0;

    write = 0;

    case(state)
      WAIT: begin
        if (tran_ready) begin
          //no matter read or write we do a OUT first
          data_out = {48'd0,mempage}; // pad the data with addr
          write = 1;
          addr = 7'd5;
          endp = 4'd4;
          send_in = 0; // OUT transaction
          input_ready = 1;

          next_state = OUT;
        end 
        else begin 
          next_state = WAIT;
        end
      
      end

      OUT: begin
        if (bad) begin 
          cancel = 1;
          done = 1;
          next_state = WAIT;
        end
        else begin
          if (free) begin // protocol FSM finished one transaction
            
            if (read) begin // if this is a read transaction
              //next transaction is a IN transaction
              send_in = 1;
              input_ready = 1;
              addr = 7'd5;
              endp = 4'd8;
              next_state = DONE;
            end            
            else begin
              
              //next transaction is a out with data
              data_out = data_in; 
              write = 1;
              addr = 7'd5;
              endp = 4'd8;
              send_in = 0; // OUT transaction
              input_ready = 1;
              next_state = DONE;
            
            end 
          
          end 
          else begin
            
            next_state = OUT; // wait for downstream to be ready
          
          end
        end
      end

      DONE: begin
        if (bad) begin 
          cancel = 1;
          done = 1;
          next_state = WAIT;
        end
        else begin
          if (free & read) begin
            //data is already on the data line
            recv_ready = 1;
            done = 1;
            next_state = WAIT;
          end
          else if (free & (~read)) begin
            done = 1;
            next_state = WAIT;
          else begin 
            //not ready
            next_state = DONE;
          end
        end
      end

    endcase
  end 
endmodule

