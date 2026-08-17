`timescale 1ns / 1ns

// job is to store the interrupt ID and make mtvec_enable=1 so can jump to mtvec addr, 
// which is written by csr instructions, also loads what is stored in that interrupt_mem index to a dataram register
module interrupt_handler (
    input logic clk, reset, irq, iack, interrupt_sel,
    input logic [3:0] interrupt_id,
    input logic [31:0] mstatus, mie, interrupt_mem_addr,
    output logic mtvec_enable, interrupt_pending,
    output logic [31:0] interrupt_read_data
);
    // stores all the interrupt IDs of all the peripherals
    logic [31:0] interrupt_mem [15:0];
    // interrupt_pending prevents repeated jumps to the same location
    // so mtvec_enable is only high for 1 cycle and pc is only mtvec handle for 1 cycle
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            interrupt_pending <= 1'b0;
        else if (irq && !interrupt_pending && mstatus[3] && mie[11]) begin // are buttons mie[11]?
            interrupt_pending <= 1'b1;
            interrupt_mem[0] <= {28'b0, interrupt_id}; // only have buttons as peripheral so can hardcode as 0
        end
        else if (iack)  
            interrupt_pending <= 1'b0;
    end

    // shoudl i put an if statement to check whether interrupt_mem_addr is within right address range
    assign interrupt_read_data = (interrupt_sel) ? interrupt_mem[interrupt_mem_addr] : 32'b0; // can technically leave as 0 since buttons are the only peripheral
    assign mtvec_enable = (irq && !interrupt_pending && mstatus[3] && mie[11]) ? 1'b1 : 1'b0;

endmodule
