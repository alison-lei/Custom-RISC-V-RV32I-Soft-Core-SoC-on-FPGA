`timescale 1ns / 1ns

// Active high asynchronous reset
// _b is boolean value

module update_pc (
    input logic clk, reset, branch_b, jump_b, input logic [31:0] branch_addr, jump_addr,
    output logic [31:0] out_pc
);
    logic [31:0] pc;

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 32'b0;
        else if (jump_b)
            pc <= jump_addr;
        else if (branch_b)
            out_pc <= branch_addr;
        else
            pc <= pc + 4;
    end

    assign out_pc = pc;

endmodule