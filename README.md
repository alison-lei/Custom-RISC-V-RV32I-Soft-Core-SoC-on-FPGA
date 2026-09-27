# Custom RISC-V RV32I Soft-Core SoC on FPGA

This project features a custom RISC-V (RV32I) soft-core processor and system-on-chip, written from scratch in SystemVerilog and running on a Terasic DE2-115 (Intel/Altera Cyclone IV E). The SoC combines a hand-built CPU core with memory-mapped peripherals and a real-time graphics pipeline that drives a 240×320 ILI9341 SPI display from a double-buffered framebuffer.

The end goal is a little desk companion that plays cute, looping pixel animations — a whole computer built from the instruction set up to the pixels, made just to make doing homework more whimsical!

## Architecture

**CPU core (RV32I):** The core is organized into discrete stages — fetch, decode, execute, register file, memory stage, writeback, and PC update — sequenced by a control FSM (`FETCH → EXEC → LOAD_WAIT`). The FSM inserts wait-states so that synchronous block-RAM reads return valid data before the pipeline consumes them, and gates PC advancement and register writes so control-flow instructions (JAL/JALR) resolve with correct timing.

**Bus and peripherals:** A combinational address decoder maps CPU addresses to the appropriate target and produces a peripheral-local index. Memory-mapped peripherals include data RAM, a GPIO/button interface, and a CSR-based interrupt controller (mstatus / mie / mtvec / mepc / mcause) driven by a GPIO interrupt source. A Harvard memory architecture keeps instruction fetch and data access on separate paths so they never contend.

**Graphics pipeline:** Both framebuffers reside in a single on-chip dual-port block RAM (153,600 words × 16-bit, RGB565). One port is written by the CPU while the other is read by the display controller, so the two sides operate concurrently without arbitration — the basis for tear-free double buffering. The `lcd_controller` runs the ILI9341 power-on initialization sequence, issues per-frame windowing and memory-write commands, and streams each pixel as two bytes over SPI (MSB first) through a `spi_controller` clock divider. A swap-handshake protocol, gated on display initialization, flips the two buffers between frames and coordinates CPU writes against display reads.

**Clocking and reset:** A PLL (ALTPLL) derives the 40 MHz core clock from the board's 50 MHz oscillator, with timing constraints (SDC) covering the core and the generated SPI clock. Reset is passed through a two-stage synchronizer so it deasserts cleanly and consistently across the design.

## Repository Layout

- `rtl/` — SystemVerilog source for the CPU, bus, peripherals, and display (start at `top_processor`)
- `mem_init/` — program images loaded into instruction memory via `$readmemh`
- `sim/` — testbenches and additional simulation files
- `constraints/` — timing (`.sdc`) and pin/assignment constraints
- `signal_tap_debug.stp` — SignalTap Logic Analyzer configuration for on-chip debugging
- `top_processor.qpf` / `.qsf` — Quartus project and settings (top-level entity: `top_processor`)

## Building and Running

The project builds through the standard Quartus command-line flow. Ensure the Quartus `bin64` directory is on the `PATH`:

```powershell
$env:PATH += ";C:\intelFPGA_lite\18.0\quartus\bin64"
```

**1. Compile the design** (analysis/synthesis, fit, assemble, timing analysis):

```powershell
quartus_map top_processor
quartus_fit top_processor
quartus_asm top_processor
quartus_sta top_processor
```

This produces `output_files/top_processor.sof`. Alternatively, open `top_processor.qpf` in the Quartus GUI and use **Processing → Start Compilation**.

**2. Prepare the board.** Connect the DE2-115 over its onboard USB-Blaster (JTAG), set the **RUN/PROG** switch to **RUN**, and power it on. Confirm the cable is detected:

```powershell
jtagconfig
```

**3. Program the FPGA:**

```powershell
quartus_pgm -c USB-Blaster -m JTAG -o "p;output_files\top_processor.sof"
```

The `.sof` loads the configuration bitstream data directly into the FPGA's SRAM which is volatile and clears on power-off, so re-run the programming step after a power cycle.

To change the program the CPU runs, replace the image in `mem_init/` and recompile so it is reloaded into instruction memory.

## Work in Progress

This project is actively in development. The current focus is bringing the CPU to full functionality so that a complete software toolchain can sit on top of it: the eventual goal is to write animations in **C**, compile them to RV32I machine code, and load that binary onto the core to execute. Driving the display from C rather than hand-assembled machine code will make deploying new animations much faster — each new idea becomes a short C program rather than a hand-encoded instruction stream — which is what ultimately turns this into the flexible, animation-playing desk accessory it's meant to be.
