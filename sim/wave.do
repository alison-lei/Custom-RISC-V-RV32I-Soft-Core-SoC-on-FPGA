vlib sim/work
vmap work sim/work
vlog -f filelist_core.f
vsim -wlf sim/vsim.wlf work.top_processor

# recursively logs to see internal signals of submodules
log -r {/*}
add wave -r {/*}

force clk 0 0ns, 1 5ns -repeat 10ns 
force {reset} 1
run 20ns
examine /top_processor/reg_f0/register_array
force {reset} 0
run 5ns
examine /top_processor/reg_f0/register_array
run 200ns

echo "__simulation_results__"
# examine / means from the root of simulation, so where you instantiate top module
echo "Operation type: [examine /top_processor/ALU_ctrl]"
echo "final data value: [examine /top_processor/last_reg_data]"
echo "final_reg_num: [examine /top_processor/last_reg_num]"
