vlib work
vlog -f ../filelist_core.f
vsim top_processor

# recursively logs to see internal signals of submodules
log -r {/*}
add wave -r {/*}

force clk 0 0ns, 1 5ns -repeat 10ns 
force {reset} 1
run 20ns
force {reset} 0
run 200ns
