`timescale 1ns / 1ns

module writeback (
    input logic ld_enable,
    input logic [31:0] ex_final_reg_data, mem_stage_rd_data,
    output logic [31:0] last_reg_data
);
    assign last_reg_data = (ld_enable) ? mem_stage_rd_data : ex_final_reg_data;

endmodule
