/** @brief Pipeline to process data output and input
 *
 *  @author Xiaofan Li
 */

`include "primitives.sv"
`include "bitstream_enc.sv"
`include "crc.sv"
`include "bit_stuff.sv"
`include "NRZI.sv"
`include "to_usb.sv"

//directly write to the output usb wires
 module pipeOut
(input logic clk, rst_L,
 input logic [3:0] pid, endp,
 input logic [6:0] addr,
 input logic pktready_bs,
 input logic [63:0] data,
 usbWires wires);
 
  //testbench style to talk to the bitstream encoder
  logic pause_bit_stuff;
  logic outb_bs,sending_bs,gotpkt_bs;
  logic pause_bs, pause_crc, outb_crc, outb_bit, outb_nrzi;
  logic sending_nrzi, pktend, usb_ready, sop;
  
  bitstream_encoder be(.pause(pause_bs),.pktready(pktready_bs),
        .outb(outb_bs),.sending(sending_bs),.gotpkt(gotpkt_bs),
        .start(sop),.*);
  crc c(.pause_out(pause_bit_stuff),.inb(outb_bs),.recving(sending_bs),
        .pause_in(pause_crc),.outb(outb_crc),.sending(sending_crc),
        .start(sop),.*);
  bit_stuff bs(.inb(outb_crc),.outb(outb_bit),.pause(pause_bit_stuff),
        .start(sop),.*);
  nrzi n(.inb(outb_bit),.outb(outb_nrzi),.*);
  to_usb tu(.data_bit(outb_nrzi),.data_start(sending_bs),.data_end(pktend),
        .d_p(wires.DP),.d_m(wires.DM),.ready(usb_ready),.*);
  
  assign pktend = (~sending_bs) & (~sending_crc),
         pause_bs = pause_bit_stuff | pause_crc;

endmodule
