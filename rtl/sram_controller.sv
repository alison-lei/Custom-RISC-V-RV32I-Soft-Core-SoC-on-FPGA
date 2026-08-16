`timescale 1ns / 1ns

module sram_controller (
    input logic clk, cpu_we,
    input logic [31:0] cpu_sram_addr,
    input logic [19:0] lcd_sram_addr,
    input logic [15:0] cpu_wdata,
    output logic [15:0] lcd_rdata,
    output logic [19:0] SRAM_ADDR,
    inout logic [15:0] SRAM_DQ,
    output logic SRAM_UB_N, SRAM_LB_N, SRAM_CE_N, SRAM_OE_N, SRAM_WE_N
);
    // if writing, we are driving DQ, if reading, chip is driving DQ
    assign SRAM_UB_N = 1'b0;
    assign SRAM_LB_N = 1'b0;
    assign SRAM_CE_N = 1'b0; // always select the chip, is active low regardless or read or write

                                    // get the last 20 bits of 32-bit cpu address
    assign SRAM_ADDR = (cpu_we) ? cpu_sram_addr[0 +: 20] : lcd_sram_addr;
    assign SRAM_DQ = (cpu_we) ? cpu_wdata : 16'hzzzz; // since reading, chip will drive DQ
    assign lcd_rdata = SRAM_DQ;
    assign SRAM_WE_N = (cpu_we) ? 1'b0 : 1'b1; // active low so pull it to 0 if writing
    assign SRAM_OE_N = (cpu_we) ? 1'b1 : 1'b0;
    
endmodule
