create_clock -name clk -period 20.000 [get_ports clk]
derive_clock_uncertainty

create_generated_clock -name sclk_gen -source [get_ports clk] -divide_by 10 [get_registers {lcd_controller:lcd_contr|spi_controller:spi0|sclk}]