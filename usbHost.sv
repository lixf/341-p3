// Write your usb host here.  Do not modify the port list.

`include "primitives.sv"
`include "bitstream_enc.sv"
`include "crc.sv"
`include "bit_stuff.sv"
`include "NRZI.sv"
`include "to_usb.sv"

module usbHost
  (input logic clk, rst_L, 
  usbWires wires); 
  
  task prelabRequest
  // sends an OUT packet with ADDR=5 and ENDP=4
  // packet should have SYNC and EOP too
  (input bit  [7:0] data);
    
    //instaniate all modules
    @(posedge clk);
    pid <= 4'b0001;
    addr <= 7'd5;
    endp <= 4'd4;
    pktready_bs <= 1;
    ##1;
    pktready_bs <= 0;
    ##30;
     
  endtask: prelabRequest

  task readData
  // host sends memPage to thumb drive and then gets data back from it
  // then returns data and status to the caller
  (input  bit [15:0]  mempage, // Page to write
   output bit [63:0] data, // array of bytes to write
   output bit        success);

  endtask: readData

  task writeData
  // Host sends memPage to thumb drive and then sends data
  // then returns status to the caller
  (input  bit [15:0]  mempage, // Page to write
   input  bit [63:0] data, // array of bytes to write
   output bit        success);

  endtask: writeData
  
  //use clocking
  default clocking myDelay
    @(posedge clk);
  endclocking 
  
  //signal for RW FSM
  logic read, tran_ready; // Set by top task!
  logic recv_ready_up; // the recv_ready signal to pass up
  logic [63:0] data_down_rw;  // DATA from top task!
  logic [63:0] data_up_rw;    // DATA report to task!
  //mempage is implicit
  logic trans_finish, unsuccess; // passed up
  logic free;             // to R/W FSM
  logic bad;              // from protocol FSM
  //recv_ready passed up 
  logic [63:0] data_down_pro;
  logic [63:0] data_up_pro; 
  logic send_in;          // from R/W FSM to send a IN 
  logic input_ready;      // control signal from R/W FSM
  logic [6:0] addr; 
  logic [3:0] endp;    
   
  // protocol FSM signals
  logic [63:0] data_out_pro;  //out of the protocol
  logic [63:0] data_in_pro;   //into the protocol
  logic cancel;          // cancel this transaction
  logic recv_ready;      // data received and ready to be read
  
  logic down_input;       // control signal from down stream
  logic down_ready;       // if the downstream is ready to receive
  logic corrupted;        // asserted if the data is corrupted
  logic ack;              // received a ack
  logic nack;             // received a nack
  logic pktready;        // to downstream senders
  logic [3:0] pid_out; 
  logic [6:0] addr_out; 
  logic [3:0] endp_out;

  // pipeline-out signals


  // The top module for all usb moules
  ReadWrite rw(.recv_ready_pro(recv_ready),.recv_ready(recv_ready_up),
               .done(tran_finish),.cancel(unsuccess),.*);
  ProtocolFSM pro(.data(data_down_pro),.data_in(data_in_pro),
                  .data_recv(data_up_pro),.data_out(data_out_pro).*);
  pipeIn pi();
  pipeOut po(.pid(pid_out),.endp(endp_out),.addr(addr_out),
             .pktready_bs(pktready),.data(data_out_pro),.*);


endmodule: usbHost
