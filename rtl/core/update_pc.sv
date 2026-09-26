`timescale 1ns / 1ns

// Active high asynchronous reset
// _b is boolean value

module update_pc (
    input logic clk, reset, pc_enable, branch_b, jump_b, mret_enable, mtvec_enable,
    input logic [31:0] branch_addr, jump_addr, mepc, mtvec,
    output logic [31:0] out_pc
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            out_pc <= 32'b0;
        else if (!pc_enable)
            out_pc <= out_pc;
        else if (mret_enable)
            out_pc <= mepc;
        else if (mtvec_enable)
            out_pc <= mtvec;
        else if (jump_b)
            out_pc <= jump_addr;
        else if (branch_b)
            out_pc <= branch_addr;
        else
            out_pc <= out_pc + 4;
    end

endmodule