// Write your usb host here.  Do not modify the port list.

`inlcude "primitives.sv"
`include "bitstream_enc.sv"


module usbHost
  (input logic clk, rst_L, 
  usbWires wires);
 
    //testbench style to talk to the bitstream encoder
    local logic pause,pktready;
    local logic inb,outb,sending,gotpkt;
    local logic [3:0] pid, endp;
    local logic [6:0] addr;
    local logic [63:0] data;
  
  /* Tasks needed to be finished to run testbenches */

  task prelabRequest
  // sends an OUT packet with ADDR=5 and ENDP=4
  // packet should have SYNC and EOP too
  (input bit  [7:0] data);
    
    //instaniate all modules
    bitstream_encoder be(.*);

    @(posedge clk);
    pid <= 4'b0001;
    addr <= 7'd5;
    endp <= 4'd4;
    pktready <= 1;
    @(posedge clk);
    pktready <= 0;
    if (~gotpkt) $display("packet sent but not received??");
    @(posedge clk);
  
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

  // usbHost starts here!!


endmodule: usbHost
