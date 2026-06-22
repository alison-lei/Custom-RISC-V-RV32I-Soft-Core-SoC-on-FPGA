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

vlib sim/work
vmap work sim/work
vlog -f filelist_core.f
vsim -wlf sim/vsim.wlf work.top_processor

log -r {/*}
add wave -r {/*}

force clk 0 0ns, 1 5ns -repeat 10ns

# ── Reset ────────────────────────────────────────────────────────────────────
force {reset} 1
run 20ns
echo "--- \[RESET\] reg file should be zeroed ---"
examine /top_processor/reg_f0/register_array
force {reset} 0

# ── ADDI x1, x0, 1  (x1 = 1) ────────────────────────────────────────────────
echo "--- \[ADDI x1=1\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000001" } {
    echo "  PASS: x1 = 1"
} else {
    echo "  FAIL: x1 expected 00000001, got $result"
}
run 10ns

# ── ADDI x2, x0, 2  (x2 = 2) ────────────────────────────────────────────────

echo "--- \[ADDI x2=2\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000002" } {
    echo "  PASS: x2 = 2"
} else {
    echo "  FAIL: x2 expected 00000002, got $result"
}
run 10ns

# ── ADD x3, x0, x2  (x3 = 2) ────────────────────────────────────────────────

echo "--- \[ADD x3 = x0+x2 = 2\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000002" } {
    echo "  PASS: x3 = 2"
} else {
    echo "  FAIL: x3 expected 00000002, got $result"
}
run 10ns

# ── SUB x8, x3, x1  (x8 = 1) ────────────────────────────────────────────────
echo "--- \[SUB x8 = x3-x1 = 1\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000001" } {
    echo "  PASS: x8 = 1"
} else {
    echo "  FAIL: x8 expected 00000001, got $result"
}
run 10ns

# ── LUI x5, 0 ────────────────────────────────────────────────────────────────

echo "--- \[LUI x5=0\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000000" } {
    echo "  PASS: x5 = 0"
} else {
    echo "  FAIL: x5 expected 00000000, got $result"
}
run 10ns
# ── ADDI x5, x5, 0x340  (x5 = 0x340) ────────────────────────────────────────

echo "--- \[ADDI x5=0x340 - store address\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000340" } {
    echo "  PASS: x5 = 0x340"
} else {
    echo "  FAIL: x5 expected 00000340, got $result"
}
run 10ns
# ── SW x5, 0(x0)  — store 0x340 to mem[0] ───────────────────────────────────

echo "--- \[SW - store x5 to mem\[0\]\] ---"
echo "  ALU_ctrl: [examine -hex /top_processor/store_enable]"
# SW has no writeback — just confirm ALU_ctrl indicates a store
set ctrl [examine -hex /top_processor/store_enable]
if { $ctrl == "1" } {
    echo "  PASS: indicates store"
} else {
    echo "  FAIL: got $ctrl"
}
run 10ns

# ── LW x2, 0(x5)  — load from mem[x5] ──────────────────────────────────────

echo "--- \[LW - load from mem\[x5\] into x2\] ---"
set result [examine -hex /top_processor/last_reg_data]
if { $result == "00000340" } {
    echo "  PASS: loaded 0x340 from memory"
} else {
    echo "  FAIL: LW expected 00000340, got $result"
}
run 10ns
# ── BEQ x2, x3  — should NOT branch (x2=0x340, x3=2) ───────────────────────

echo "--- \[BEQ x2,x3 - expect NO branch\] ---"
set pc [examine -hex /top_processor/current_pc]
if { $pc == "00000024" } {
    echo "  PASS: PC advanced sequentially (no branch)"
} else {
    echo "  FAIL: BEQ expected PC=00000024, got $pc"
}
run 10ns
# ── BNE x2, x3  — should branch ─────────────────────────────────────────────

echo "--- \[BNE x2,x3 - expect branch taken\] ---"
set pc [examine -hex /top_processor/current_pc]
if { $pc == "00000034" } {
    echo "  PASS: branch taken, PC jumped"
} else {
    echo "  FAIL: BNE expected PC=00000034, got $pc"
}
run 10ns
# ── JAL x0, +4  — unconditional jump ────────────────────────────────────────

echo "--- \[JAL - unconditional jump\] ---"
set pc [examine -hex /top_processor/current_pc]
if { $pc == "00000038" } {
    echo "  PASS: JAL jumped correctly"
} else {
    echo "  FAIL: JAL expected PC=00000038, got $pc"
}
run 10ns
# ── Final register file dump ─────────────────────────────────────────────────
echo ""
echo "=== FINAL REGISTER FILE ==="
examine /top_processor/reg_f0/register_array

echo ""
echo "=== SIMULATION COMPLETE ==="