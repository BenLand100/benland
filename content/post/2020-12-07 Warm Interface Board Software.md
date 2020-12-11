---
title: DUNE Warm Interface Board (WIB) Software
date: '2020-12-07'
categories:
  - Physics
  - Programming
slug: dune-wib
---

![DUNE experiment overview](/images/lbne_sketch.png)
The [DUNE](https://www.dunescience.org/) experiment will transfer a massive amount of digitized analog signals from the wire planes, which collect electrons ionized by high energy particles produced in neutrino interactions, to software that decides whether or not the current state of the detector is interesting enough to store for future analysis.
Sitting in the middle of this infrastructure is the Warm Interface Board (WIB) which controls and configures the front end electronics (responsible for digitizing the analog signals), aggregates data from a segment of the front end via electrical signals over copper cables, and transfers this data over 40gbps optical links to the upstream data acquisition system (responsible for storing the interesting data).

The WIB, therefore, needs to be able to receive high-level configuration and monitoring commands from upstream systems, and send the appropriate low-level commands to downstream systems.
It is based on a [Xilinx Zynq Ultrascale+ FPGA](https://www.xilinx.com/products/silicon-devices/fpga/virtex-ultrascale-plus.html) with the idea that the PL side will provide [AXI](https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface) register mapped hardware interfaces to the front end electronics and handle the high speed data streams, while the PS side (consisting of two or four ARM cores) will run software that receives commands over a 1gbps ethernet link as TCP packets and translate these into the appropriate hardware state changes.

## Big data alphabet soup

The WIB controls four frontend motherboards (FEMBs) submerged in liquid argon.
Each FEMB contains two COLDATA [ASICs](https://en.wikipedia.org/wiki/Application-specific_integrated_circuit) designed specifically for DUNE, which control the logic on the frontend.
Each COLDATA controls four COLDADC 16-channel analog-to-digital converters ASICs which are connected to 16-channel LArASIC low noise amplifiers.
The LArASICs are connected to the collection (induction) wires, which will measure voltage fluctuations when ionized electrons from a physics interaction are produced.
These channels will each sample 14bit values at 2 MHz.

Four WIBs will be needed per anode plane assembly (APA), and 150 APAs are planned for the full DUNE detector. That's a lot of data!

## High-level upstream interface

The [software I've designed for the WIB](https://github.com/DUNE-DAQ/dune-wib-firmware/tree/master/sw) consists of a [ZeroMQ](https://zeromq.org/) socket that receives messages serialized by [Google's protocol buffer](https://developers.google.com/protocol-buffers) libraries to ensure cross platform compatibility. 
You can find the protobuf messages [here](https://github.com/DUNE-DAQ/dune-wib-firmware/tree/master/sw/src/wib.proto).
The ZeroMQ socket is setup in `REP` mode to allow it to gracefully respond to messages from any number of clients in a serial fashion. 
The server on the WIB will accept `Command` messages that include another message as a protobuf `Any` type, with any other data on the socket being safely ignored.
For messages that the server expects, the server will take some action, and return another protobuf message. 
If an unexpected message is received, the server will return an empty packet as a failsafe.

This is the first time I've used ZeroMQ + protobuf, and it works quite well for remote control and monitoring, while avoiding issues that might arise from trying to serialize C(++) structs on differing platforms (the WIB is ARM, while most control devices will be x86_64). 
Several interface programs are included in the software repository above. 
Since most of the upstream software will be written in C++, I've provided [reference implementations](https://github.com/DUNE-DAQ/dune-wib-firmware/blob/master/sw/src/wib_client.cxx) for communicating with the WIB's ZeroMQ serer.
This has made it trivial to integrate the WIB configuration and control into existing upstream software.
The cross-platform cross-language nature of ZeroMQ and protobuf is leveraged with some very simple Python debugging tools using [PyQt5](https://pypi.org/project/PyQt5/) and [matplotlib](https://matplotlib.org/) to provide visual readout of digitized data.
