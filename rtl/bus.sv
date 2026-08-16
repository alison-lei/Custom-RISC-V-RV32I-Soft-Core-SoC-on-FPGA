`timescale 1ns / 1ns

module bus (
    input logic reset,
    input logic [31:0] addr,
    output logic dataram_sel, interrupt_sel, framebuffer_sel,
    output logic [31:0] target_mem_indx
);

    // need to do base offset so the index of each memory alloc is correct
    always_comb begin
        dataram_sel = 1'b0;
        interrupt_sel = 1'b0;
        framebuffer_sel = 1'b0;
        target_mem_indx = 32'b0;

        if (!reset) begin
            if (addr >= 32'h00005000 && addr <= 32'h000058FF) begin
                dataram_sel = 1'b1;
                target_mem_indx = addr - 32'h00005000;
            end
            else if (addr >= 32'h00005900 && addr <= 32'h000059FF) begin
                interrupt_sel = 1'b1;
                target_mem_indx = addr - 32'h00005900;
            end
            else if (addr >= 32'h00006000 && addr < 32'h0009F200) begin // = 32'h0002D100 is the start of buffer B
                framebuffer_sel = 1'b1;
                target_mem_indx = addr - 32'h00006000;
            end
        end
        
    end

endmodule
