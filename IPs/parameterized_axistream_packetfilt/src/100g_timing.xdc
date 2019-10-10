create_clock -period 3.103 -name fast_clk -waveform {0.000 1.552} [get_ports axi_aclk]
set_input_jitter [get_clocks -regexp -nocase .*] 0.300
