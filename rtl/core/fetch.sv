`timescale 1ns / 1ns

// byte-addresable memory

module fetch (
    input logic [31:0] addr,
    output logic [31:0] instr
);
    // elements in memory are of word granularity
    logic [31:0] memory [0:4095]; // 16KB

    initial $readmemh("compiled_program.hex", memory);

    assign instr = memory[addr >> 2];

endmodule