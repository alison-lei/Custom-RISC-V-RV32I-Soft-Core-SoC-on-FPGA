vlib sim/work_display
vmap work sim/work_display
vlog -f filelist_core.f
vsim -wlf sim/vsim.wlf work.lcd_spi_sram_tb

log -r {/*}
add wave -r {/*}

run 3ms