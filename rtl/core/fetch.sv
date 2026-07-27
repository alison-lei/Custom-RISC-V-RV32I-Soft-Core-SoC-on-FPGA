`timescale 1ns / 1ns

// byte-addresable memory

module fetch (
    input logic [31:0] addr,
    output logic [31:0] instr
);
    // elements in memory are of word granularity
    logic [31:0] memory [0:4095]; // 16KB

    // when do reset initially, pc is 0, adds by 4 incrementally
    // the first instruction is when pc = 0, so when reset = 1, 
    initial $readmemh("mem_init/testing.hex", memory);

    always_comb begin
        instr = 32'h00000013; // NOP, no operation default ADDI x0, x0, 0
        if (addr <= 32'h00000FFF)
            instr = memory[addr >> 2];
    end

endmodule