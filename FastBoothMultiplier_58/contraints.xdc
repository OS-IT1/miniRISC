#//////////////////////////////////////////////////////////////////////////////////
#// Group Number: 58
#// Group Members (Name and Roll Number):
#// 1. Rishi Songirkar(24CS10071)
#// 2. Tirth Patel (24CS10046)
#// Course: Computer Organization and Architecture Laboratory
#// Assignment: Verilog Assignment 6
#// Problem: Fast Boot Multiplier
#// Date: 07/09/2026
#//////////////////////////////////////////////////////////////////////////////////

set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {clk}]
create_clock -period 16.000 -name clk100mhz -waveform {0.000 8.000} [get_ports {clk}]