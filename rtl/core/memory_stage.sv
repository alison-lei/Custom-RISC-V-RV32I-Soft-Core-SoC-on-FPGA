`timescale 1ns / 1ns

module memory_stage (
    input logic ld_enable,
    input logic dataram_sel, interrupt_sel,
    input logic [31:0] dataram_read_data, interrupt_read_data,

    output logic [31:0] mem_stage_rd_data
);
    // use mux to determine which peripheral read_data wire controls mem_stage_rd_data
    always_comb begin
        if (dataram_sel)
            mem_stage_rd_data = dataram_read_data;
        else if (interrupt_sel)
            mem_stage_rd_data = interrupt_read_data;
    end
    
endmodule
