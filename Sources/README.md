Brief summary of each file:

- **`alu.v`**: The dumbest ALU on Earth. Instantiated inside `bpfvm_datapath.v` as part of the CPU core.
- **`bpfvm_ctrl.v`**: An FSM controller for the CPU core. I may pipeline this controller one day.
- **`bpfvm_datapath.v`**: The BPF CPU core's datapath. This instantiates `alu.v` and `regfile.v`
- **`codemem.v`**: A simple Verilog file synthesized as a BRAM in simple dual-port mode. Used as the CPU's instruction memory
- **`packetmem.v`**: Probably the most fiddly module. Instantiates two `packetram.v`s as a ping and pong buffer, and sends all the right backpressure signals and stuff to the three people trying to read and write to these buffers (the snoopers, CPU core, and forwarders)
- **`packetram.v`**: Simple dual-port BRAM designed for use in `packetmem.v`
- **`regfile.v`**: A simple register file (instantiated in `bpfvm_datapath.v`) implemented as distributed RAM.

Refer to the Wiki for a high-level view of how these modules are all connected together. Also, the files themselves have some extra details in a comment at the top of the file.
