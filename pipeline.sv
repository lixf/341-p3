/** @brief Pipeline to process data output and input
 *
 *  @author Xiaofan Li
 */


//directly write to the output usb wires
 module pipeOut
(input logic clk, rst_L,
 input logic [3:0] pid, endp,
 input logic [6:0] addr,
 input logic pktready_bs,
 input logic [63:0] data,
 input logic pkttype,
 output logic down_ready,
 output logic sending_usb,
 output logic usb_dp,
 output logic usb_dm);
 
  //testbench style to talk to the bitstream encoder
  logic pause_bit_stuff;
  logic outb_bs,sending_bs,gotpkt_bs;
  logic pause_bs, pause_crc, outb_crc, outb_bit, outb_nrzi;
  logic sending_nrzi, pktend, usb_ready, sop;
  //logic nrzi_start;

  bitstream_encoder be(.pause(pause_bs),.pktready(pktready_bs),
        .outb(outb_bs),.sending(sending_bs),.gotpkt(gotpkt_bs),
        .start(sop),.*);
  crc c(.pause_out(pause_bit_stuff),.inb(outb_bs),.recving(sending_bs),
        .pause_in(pause_crc),.outb(outb_crc),.sending(sending_crc),
        .start(sop), .clear(1'b0), .*);
  bit_stuff bs(.inb(outb_crc),.outb(outb_bit),.pause(pause_bit_stuff),
        .start(sop),.*);
  nrzi n(.inb(outb_bit),.outb(outb_nrzi),.data_end(pktend),.data_start(sop),.*);
  to_usb tu(.data_bit(outb_nrzi),.data_start(sending_bs),.data_end(pktend),
        .d_p(usb_dp),.d_m(usb_dm),.ready(usb_ready),.sending(sending_usb),.*);
  
  assign pktend = (~sending_bs) & (~sending_crc),
         pause_bs = pause_bit_stuff | pause_crc;
  
endmodule

module pipeIn
(input logic clk, rst_L, writing,
 output logic [63:0] data,
 output logic pktready, error, ack, nak,
 input logic usb_dp,
 input logic usb_dm);

  logic pause;
  logic in_bitstream, nrzi_out, bitunstuff_out;
  logic bitus_sending, in_sending;
  logic eop, dec_recv;
  
  assign dec_recv = (~writing) & in_sending; 

  from_usb fu(.d_p(usb_dp),.d_m(usb_dm),.enable_read(~writing),.outb(in_bitstream),
              .sending(in_sending),.*);

  nrzi_decode n(.inb(in_bitstream), .outb(nrzi_out), .recving(in_sending), .*);

  bit_unstuff bu(.inb(nrzi_out), .recving(dec_recv), .sending(bitus_sending),
                 .outb(bitunstuff_out), .*);

  bitstream_decoder bd(.recving(bitus_sending), .inb(bitunstuff_out), 
                       .havepkt(pktready), .haveack(ack), .havenak(nak), .*);

endmodule
