`timescale 1ns / 1ns

// need to figure out whether i need a writeback, and separate reading values from register, writing values to registers, loading and storing from and to RAM

/*
No — and this is an important principle. In hardware you don't have functions the way software does.
A module is the hardware equivalent of a function, but it physically exists as a circuit.
If you copy the register file logic into execute, you're describing a
second register file in hardware — two separate arrays of 32 registers.
That's not what you want.
The register file is instantiated once at the top level and its read/write ports are wired to wherever they're needed.
It's shared hardware, not reusable code.

*/

module register_file (
    input logic clk, reset, rd_enable, input logic [4:0] rs1_num, rs2_num, rd_num, input logic [31:0] rd_data,
    output logic [31:0] rs1_data, rs2_data
);
    // Create 2D array, 32 registers each 32 bits
    logic [31:0] register_array [31:0];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 32; i++)
                register_array[i] <= 32'b0;
        end
        else if (rd_enable and rd_num != 5'b0)
            register_array[rd_num] <= rd_data;
            // do i need to do a separate if else statement if rd_num is 5'b0
    end

    assign rs1_data = (rs1_num == 5'b0) ? 32'b0 : register_array[rs1_num];
    assign rs2_data = (rs2_num == 5'b0) ? 32'b0 : register_array[rs2_num];

endmodule