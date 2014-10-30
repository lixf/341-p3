18341-Lab 3 USB Host 
=========

Introduction
----

This document is written in *markdown*, and it describes some of the design choices in the USB lab for 18341. (It looks pretty on GitHub, and is easy to write.)

Components
-----------

The USB host uses the following high-level modules:

* Read/Write FSM - A FSM that talks with the Read/Write tasks and sends commands to the ProtocolFSM (by [@xli2])
* Protocol FSM - Composed of two parts (by [@xli2]):
    * Out Protocol FSM - Handles all OUT *transactions* by using the OUT pipeline.
    * In Protocol FSM - Handles all IN *transactions* by using the IN pipeline.
* Pipelines - Composed of two parts (by [@cwill]):
    * Out pipeline - Contains bitstream encoder, CRC generator, bit stuffer, NRZI and to_usb.
    * In pipeline - Contains bitstream decoder, CRC checker, bit unstuffer, NRZI and from_usb.

Handshakes
--------------

from *Task* to *R/W FSM*:

```verilog
 //from the read/write task
 input logic read,            // asserted when read
 input logic tran_ready,      // transaction is ready
 input logic [15:0] rw_addr,  // the address used for read/write
 input logic [63:0] data_down_rw,  // data to write from R/W FSM

 //from protocol FSM
 input logic free,            // if the protocol FSM is able to send
 input logic bad,             // need to cancel the transaction
 input logic recv_ready_pro,  // FORWRD UP
 input logic [63:0] data_up_pro,

 //to protocol FSM
 output logic send_in,        // send an IN transaction
 output logic input_ready,    // Protocol FSM has valid input from us
 output logic got_result,
 output logic [6:0] addr,
 output logic [3:0] endp,
 output logic [63:0] data_down_pro,

 //to read/write task
 output logic [63:0] data_up_rw, // the data to write out or read in
 output logic recv_ready,      // the received packet is ready 
 output logic done,            // the transaction is done 
 output logic cancel;         // if we failed forwarded from protocol

``` 
from *R/W FSM* to *Protocol FSM*
 
```verilog 
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
 output logic [3:0] endp_out;
 
```
from *Protocol FSM* to *Pipelins*

```verilog
 input logic [3:0] pid,
 input logic [3:0]endp,       //the pid and end to send
 input logic [6:0] addr,      //the addr to send
 input logic pktready_bs,     //ready signal from OUT protocol FSM
 input logic [63:0] data,     //data from OUT protocol FSM
 input logic pkttype,         //the type of CRC being used (asserted for CRC16)
 output logic down_ready,     //output to protocol FSM if pipeline is ready
 output logic sending_usb,    //output to protocol FSM if pipeline to writing to USB
 output logic usb_dp,         //USB connections
 output logic usb_dm;

```
```verilog
 input logic writing,         //if the other pipeline is writing to USB 
 output logic [63:0] data,    //data that we received
 output logic pktready,       //if data is ready
 output logic error, ack, nak,//if any error or ack/nack is received
 input logic usb_dp,          //USB wires
 input logic usb_dm;

```
Internal signals from pipeline are omitted for brevity, but the fundamental
approach for all the pipeline modules is the same:  We maintain a ready signal
and a sending (or receiving) signal for all the components of the pipeline,
which allows each to depend only on the previous step's output.  The exception
to this is the bit stuffer module, which in both pipelines has a pause signal
which is sent out to the rest of the pipeline after it to instruct them to
wait for a stuffed bit and take no action for a clock tick. A top-level
sending/receiving signal is used essentially as a lock on the USB wires to
prevent attempts to write and read at the same time.





[@xli2]:http://github.com/lixf
[@cwill]:https://github.com/cwill


