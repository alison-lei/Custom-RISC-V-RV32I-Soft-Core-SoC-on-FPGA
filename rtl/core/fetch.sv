`timescale 1ns / 1ns

// byte-addresable memory

module fetch (
    input logic [31:0] addr,
    output logic [31:0] instr
);
    // elements in memory are of word granularity
    logic [31:0] memory [0:4095]; // 16KB

    // when do reset initially, pc is 0, adds by 4 incrementally
    // the first instruction is when pc = 0, so when reest = 1, 
    initial $readmemh("mem_init/testing.hex", memory);

    assign instr = memory[addr >> 2];

endmodule