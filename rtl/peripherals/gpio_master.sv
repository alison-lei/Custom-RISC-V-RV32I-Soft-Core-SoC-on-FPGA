`timescale 1ns / 1ns

module gpio_master (
    input logic clk, reset, iack,
    input logic [3:0] buttons, // assign values in top_processor, 4 bits for 4 buttons
    output logic irq,
    output logic [3:0] interrupt_id // assume for now 4 buttons
);
    // removed gpio_mem because no other modules need to read data from there
    
    localparam int DEBOUNCER_CLK_CYCLES = 1000;
    int but0_clk_count = 0;
    int but1_clk_count = 0;
    int but2_clk_count = 0;
    int but3_clk_count = 0;

    always_ff @(posedge clk or posedge reset) begin
        interrupt_id <= 4'b0;

        if (reset) begin
            irq <= 1'b0;
            but0_clk_count <= 0;
            but1_clk_count <= 0;
            but2_clk_count <= 0;
            but3_clk_count <= 0;
        end
        else if (buttons != 4'b000) begin
            if (buttons[0]) begin
                if (but0_clk_count == DEBOUNCER_CLK_CYCLES - 1) begin
                    interrupt_id[0] <= 1'b1;
                    but0_clk_count <= 0;
                    irq <= 1'b1;
                end
                else    
                    but0_clk_count <= but0_clk_count + 1;
            end
            else if (buttons[1]) begin
                if (but1_clk_count == DEBOUNCER_CLK_CYCLES - 1) begin
                    interrupt_id[1] <= 1'b1;
                    but1_clk_count <= 0;
                    irq <= 1'b1;
                end
                else
                    but1_clk_count <= but1_clk_count + 1;
            end
        end
        else begin
            but0_clk_count <= 0;
            but1_clk_count <= 0;
            but2_clk_count <= 0;
            but3_clk_count <= 0;
        end

        if (iack)
            irq <= 1'b0;
    end

endmodule
