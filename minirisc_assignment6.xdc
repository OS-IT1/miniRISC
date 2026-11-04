# MiniRISC Assignment 6 constraints (single file: use this INSTEAD of contraints.xdc).
# 14 ns = ~71.4 MHz. The fetch/execute loop needs ~11.5 ns; 14 ns leaves margin.
# The timing-simulation testbench must use the same period (half period = 7 ns).
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -name processor_clk -period 80.000 [get_ports clk]

# Booth multiplier: operands are latched by load_inputs and held while the
# multiplier FSM spends two cycles (COMPUTE1, COMPUTE2) before loading prod_reg.
# Verify these patterns match cells in your netlist: get_cells -hier *mc_reg_reg*
set mul_src [get_cells -hier -filter {NAME =~ *dp/mc_reg_reg* || NAME =~ *dp/mp_reg_reg*}]
set mul_dst [get_cells -hier -filter {NAME =~ *dp/prod_reg_reg*}]
set_multicycle_path -setup 2 -from $mul_src -to $mul_dst
set_multicycle_path -hold  1 -from $mul_src -to $mul_dst