`timescale 1ns / 1ns

// byte-addresable memory

module fetch (
    input logic [31:0] addr,
    output logic [31:0] instr
);
    // internal block RAM that FPGA initializes. Not on same bus as dataram, harvard architecture
    logic [31:0] memory [0:5119]; // 0x4FFF

    // when do reset initially, pc is 0, adds by 4 incrementally
    // the first instruction is when pc = 0, so when reset = 1, 
    initial begin
        // would set all initally to 0, but quartus restricts forloop to 5000, isok b/c although warning
        // default resorts back to 0
        // for (int i = 0; i < 5120; i++)
        //     memory[i] = 32'b0;
        $readmemh("mem_init/testing.hex", memory);
    end

    always_comb begin
        instr = 32'h00000013; // NOP, no operation default ADDI x0, x0, 0
        if (addr <= 32'h00004FFF)
            instr = memory[addr >> 2];
    end

endmodule