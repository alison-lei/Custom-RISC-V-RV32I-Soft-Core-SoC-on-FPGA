`timescale 1ns / 1ns

module writeback (
    input logic clk, reset, mem_stage_enable,
    input logic [4:0] 

    output logic [4:0] last_reg_num,
    output logic [31:0] last_reg_data
);

always_ff @(posedge clk or posedge reset) begin
    if (reset)
        last_reg_data = 

end





endmodule
