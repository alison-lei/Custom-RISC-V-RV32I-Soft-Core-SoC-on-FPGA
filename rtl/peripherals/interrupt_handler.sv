`timescale 1ns / 1ns

module interrupt_handler (
    input logic clk, reset, irq, iack, interrupt_sel,
    input logic [3:0] interrupt_id,
    input logic [31:0] mstatus, mie, mem_addr,
    output logic mtvec_enable, interrupt_pending,
    output logic [31:0] interrupt_read_data
);
    logic [31:0] interrupt_mem [15:0];
    // interrupt_pending prevents repeated jumps to the same location
    // so mtvec_enable is only high for 1 cycle and pc is only mtvec handle for 1 cycle
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            interrupt_pending <= 1'b0;
        else if (irq && !interrupt_pending && mstatus[3] && mie[11]) begin
            interrupt_pending <= 1'b1;
            interrupt_mem[0] <= {28'b0, interrupt_id};
        end
        else if (iack)
            interrupt_pending <= 1'b0;
    end

    assign interrupt_read_data = (interrupt_sel) ? interrupt_mem[mem_addr] : 32'b0;
    assign mtvec_enable = (irq && !interrupt_pending && mstatus[3] && mie[11]) ? 1'b1 : 1'b0;

endmodule
