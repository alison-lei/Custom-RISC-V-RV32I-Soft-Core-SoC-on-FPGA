vlib sim/work
vmap work sim/work
vlog -f filelist_core.f
vsim -wlf sim/vsim.wlf work.top_processor

log -r {/*}
add wave -r {/*}

force clk 1 0ns, 0 5ns -repeat 10ns

force {reset} 1
run 20ns
echo "--- \[RESET\] reg file should be zeroed ---"
examine /top_processor/reg_f0/register_array
force {reset} 0

# ── ADDI x1, x0, 1  (x1 = 1)  —  00100093 ───────────────────────────────────
echo "--- \[ADDI x1, x0, 1\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000001" } {
    echo "  PASS: x1 = 1"
} else {
    echo "  FAIL: x1 expected 00000001, got $result"
}
run 10ns

# ── ADDI x2, x0, 2  (x2 = 2)  —  00200113 ───────────────────────────────────
echo "--- \[ADDI x2, x0, 2\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000002" } {
    echo "  PASS: x2 = 2"
} else {
    echo "  FAIL: x2 expected 00000002, got $result"
}
run 10ns

# ── ADD x3, x1, x2  (x3 = 3)  —  002081B3 ───────────────────────────────────
echo "--- \[ADD x3, x1, x2\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000003" } {
    echo "  PASS: x3 = 3"
} else {
    echo "  FAIL: x3 expected 00000003, got $result"
}
run 10ns

# ── SUB x4, x3, x1  (x4 = 2)  —  40118233 ───────────────────────────────────
echo "--- \[SUB x4, x3, x1\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000002" } {
    echo "  PASS: x4 = 2"
} else {
    echo "  FAIL: x4 expected 00000002, got $result"
}
run 10ns

# ── LUI x5, 0  (x5 = 0)  —  000002B7 ────────────────────────────────────────
echo "--- \[LUI x5, 0\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000000" } {
    echo "  PASS: x5 = 0"
} else {
    echo "  FAIL: x5 expected 00000000, got $result"
}
run 10ns

# ── ADDI x5, x5, 0x340  (x5 = 0x340)  —  34028293 ───────────────────────────
echo "--- \[ADDI x5, x5, 0x340\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000340" } {
    echo "  PASS: x5 = 0x340"
} else {
    echo "  FAIL: x5 expected 00000340, got $result"
}
run 10ns

# ── SW x5, 0(x0)  —  00502023 ────────────────────────────────────────────────
echo "--- \[SW x5, 0\[x0\]\] ---"
set ctrl [examine -hex /top_processor/store_enable]
if { $ctrl == "1" } {
    echo "  PASS: store_enable high"
} else {
    echo "  FAIL: store_enable expected 1, got $ctrl"
}
run 10ns

# know what is stored at address 0 becuase previously stored with 0x340
# ── LW x6, 0(x0)  —  00002303 ────────────────────────────────────────────────
echo "--- \[LW x6, 0\[x0\]\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000340" } {
    echo "  PASS: x6 = 0x340 loaded from mem\[0\]"
} else {
    echo "  FAIL: LW expected 00000340, got $result"
}
run 10ns

# ── BEQ x1, x2  —  00208863 ──────────────────────────────────────────────────
echo "--- \[BEQ x1, x2 - expect NO branch\] ---"
set branch_b [examine /top_processor/branch_b]
if { $branch_b == "0" } {
    echo "  PASS: branch_b=0, BEQ not taken (x1!=x2)"
} else {
    echo "  FAIL: branch_b expected 0, got $branch_b"
}
run 10ns

# ── BNE x1, x2  —  00209863 ──────────────────────────────────────────────────
echo "--- \[BNE x1, x2 - expect branch taken\] ---"
set branch_b [examine /top_processor/branch_b]
if { $branch_b == "1" } {
    echo "  PASS: branch_b=1, BNE taken"
} else {
    echo "  FAIL: branch_b expected 1, got $branch_b"
}
run 10ns

# ── PC after BNE should now be branch target ──────────────────────────────────
echo "--- \[PC after BNE branch\] ---"
set pc [examine -hex /top_processor/current_pc]
if { $pc == "00000034" } {
    echo "  PASS: PC jumped to branch target"
} else {
    echo "  FAIL: expected PC=00000034, got $pc"
}

# CASE PASSES BY ACCIDENT
# Last instruction (@00000028) which is JAL tells it to just jump to next instruction
# pc = pc + 4, but since branched to 00000034, then it just does pc = pc + 4 like
# normal because not reset, nor branch_b, not jump_b
# it branched over the last jump instruction entirely
# corrected now by adding filler instructions

# evaluate jump_b right at the start of the instruction b/c if first run 10ns then it
# becomes 0 which is correct because is @ next instruction which is address of 
# what the jump instruction specified

# ── JAL x0, +4  —  0040006F ──────────────────────────────────────────────────
echo "--- \[JAL - PC during jump instruction\] ---"
set jump_b [examine -hex /top_processor/jump_b]
if { $jump_b == "1" } {
    echo "  PASS: JAL jumped correctly"
} else {
    echo "  FAIL: expected jump_b = 1, got $jump_b"
}

run 10ns
echo "--- \[JAL - PC after jump instruction\] ---"
set pc [examine -hex /top_processor/current_pc]
if { $pc == "00000038" } {
    echo " PASS: JAL jumped 4 correctly"
} else {
    echo " FAIL: expected PC=00000038, got $pc "
}


# ── Final register file dump ──────────────────────────────────────────────────
echo ""
echo "=== FINAL REGISTER FILE ==="
examine /top_processor/reg_f0/register_array

echo ""
echo "=== SIMULATION COMPLETE ==="



#vlib sim/work
#vmap work sim/work
#vlog -f filelist_core.f
#vsim -wlf sim/vsim.wlf work.top_processor
#
## recursively logs to see internal signals of submodules
#log -r {/*}
#add wave -r {/*}
#
#force clk 0 0ns, 1 5ns -repeat 10ns 

## trial run
#force {reset} 1
#run 20ns
#examine /top_processor/reg_f0/register_array
#force {reset} 0
#run 5ns
#examine /top_processor/reg_f0/register_array
#run 200ns
#
#echo "__simulation_results__"
## examine / means from the root of simulation, so where you instantiate top module
#echo "Operation type: [examine /top_processor/ALU_ctrl]"
#echo "final data value: [examine /top_processor/last_reg_data]"
#echo "final_reg_num: [examine /top_processor/last_reg_num]"
