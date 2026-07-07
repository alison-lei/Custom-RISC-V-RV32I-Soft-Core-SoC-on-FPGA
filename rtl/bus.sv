`timescale 1ns / 1ns

module bus (
    input logic reset,
    input logic [31:0] addr,
    output logic dataram_sel, gpio_sel, spi_sel, interrupt_sel,
    output logic [31:0] target_mem_indx
);

    // need to do base offset so the index of each memory alloc is correct
    always_comb begin
        dataram_sel = 1'b0;
        gpio_sel = 1'b0;
        spi_sel = 1'b0;
        interrupt_sel = 1'b0;
        target_mem_indx = 32'b0;

        if (!reset) begin
            if (addr >= 32'h00001000 && addr <= 32'h000010FF) begin
                dataram_sel = 1'b1;
                target_mem_indx = addr - 32'h00001000;
            end
            else if (addr >= 32'h00001100 && addr <= 32'h00001107) begin
                gpio_sel = 1'b1;
                target_mem_indx = addr - 32'h00001100;
            end
            else if (addr >= 32'h00001108 && addr <= 32'h0000110F) begin
                spi_sel = 1'b1;
                target_mem_indx = addr - 32'h00001108;
            end
            else if (addr >= 32'h00001110 && addr <= 32'h00001117) begin
                interrupt_sel = 1'b1;
                target_mem_indx = addr - 32'h00001110;
            end
        end
        
    end

endmodule
