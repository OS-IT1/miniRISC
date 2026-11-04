# 50 MHz processor clock. CLK_PERIOD in tb_minirisc_autonomous.v must use the same value.
create_clock -name processor_clk -period 20.000 [get_ports clk]
