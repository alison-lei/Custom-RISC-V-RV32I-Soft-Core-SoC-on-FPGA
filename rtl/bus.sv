`timescale 1ns / 1ns

module bus (
    input logic reset,
    input logic [31:0] addr,
    output logic dataram_sel, interrupt_sel,
    output logic [31:0] target_mem_index
);

    // need to do base offset so the index of each memory alloc is correct
    always_comb begin
        dataram_sel = 1'b0;
        interrupt_sel = 1'b0;
        target_mem_index = addr;

        if (!reset) begin
            if (addr >= 32'h00005000 && addr <= 32'h00005EFF) begin
                dataram_sel = 1'b1;
                target_mem_index = addr - 32'h00005000;
            end
            else if (addr >= 32'h00005F00 && addr <= 32'h00005FFF) begin
                interrupt_sel = 1'b1;
                target_mem_index = addr - 32'h00005F00;
            end
            else if (addr >= 32'h00006000 && addr < 32'h00051000) // = 32'h0002D100 is the start of buffer B
                target_mem_index = addr - 32'h00006000;
        end
        
    end

endmodule
