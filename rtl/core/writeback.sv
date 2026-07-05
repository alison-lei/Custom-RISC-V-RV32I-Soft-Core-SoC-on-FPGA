`timescale 1ns / 1ns

module writeback (
    input logic ld_enable,
    input logic [4:0] ex_final_reg_num, mem_load_reg_num,
    input logic [31:0] ex_final_reg_data, mem_load_reg_data,

    output logic [4:0] last_reg_num,
    output logic [31:0] last_reg_data
);
    always_comb begin
        if (ld_enable) begin
            last_reg_num = mem_load_reg_num;
            last_reg_data = mem_load_reg_data;
        end
        else begin
            last_reg_num = ex_final_reg_num;
            last_reg_data = ex_final_reg_data;
        end
    end
endmodule
