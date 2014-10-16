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
 
  //testbench style to talk to the bitstream encoder
  logic pause_bit_stuff,pktready_bs;
  logic outb_bs,sending_bs,gotpkt_bs;
  logic pause_bs, pause_crc, outb_crc, outb_bit, outb_nrzi;
  logic sending_nrzi, pktend, usb_ready;
  logic [3:0] pid, endp;
  logic [6:0] addr;
  logic [63:0] data;
  
  bitstream_encoder be(.pause(pause_bs),.pktready(pktready_bs),
        .outb(outb_bs),.sending(sending_bs),.gotpkt(gotpkt_bs),.*);
  crc c(.pause_out(pause_bit_stuff),.inb(outb_bs),.recving(sending_bs),
        .pause_in(pause_crc),.outb(outb_crc),.sending(sending_crc),.*);
  bit_stuff bs(.inb(outb_crc),.outb(outb_bit),.pause(pause_bit_stuff),.*);
  nrzi n(.inb(outb_bit),.outb(outb_nrzi),.*);
  to_usb tu(.data_bit(outb_nrzi),.data_start(sending_bs),.data_end(pktend),
        .d_p(wires.DP),.d_m(wires.DM),.ready(usb_ready),.*);
  
  assign pktend = ~sending_bs,
         pause_bs = pause_bit_stuff | pause_crc;
  /* Tasks needed to be finished to run testbenches */
  
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
    @(posedge clk);
    pktready_bs <= 0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
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
