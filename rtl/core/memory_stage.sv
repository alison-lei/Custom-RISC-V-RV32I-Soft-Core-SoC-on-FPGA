`timescale 1ns / 1ns

module memory_stage (
    input logic ld_enable
    input logic [4:0] final_reg_num,

    input logic dataram_sel, gpio_sel, spi_sel, interrupt_sel,
    input logic [31:0] dataram_read_data, gpio_read_data, spi_read_data, interrupt_read_data,

    output logic [31:0] load_reg_data,
    output logic [4:0] load_reg_num
);
    // use mux to determine which peripheral read_data wire controls load_reg_data
    always_comb begin
        load_reg_num = (ld_enable) ? final_reg_num : 5'b0;
        if (dataram_sel)
            load_reg_data = dataram_read_data;
        else if (gpio_sel)
            load_reg_data = gpio_read_data;
        else if (spi_sel)
            load_reg_data = spi_read_data;
        else if (interrupt_sel)
            load_reg_data = interrupt_read_data;
    end

endmodule
