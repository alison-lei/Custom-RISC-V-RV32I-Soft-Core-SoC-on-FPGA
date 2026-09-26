create_clock -name CLOCK50 -period 20.000 [get_ports CLOCK50]
derive_pll_clocks
derive_clock_uncertainty

create_generated_clock -name sclk_gen -source [get_pins {sys_pll_clk|altpll_component|auto_generated|pll1|clk[0]}] -divide_by 10 [get_registers {lcd_controller:lcd_contr|spi_controller:spi0|sclk}]