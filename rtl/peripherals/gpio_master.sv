`timescale 1ns / 1ns

module gpio_master (
    input logic clk, reset, iack,
    input logic [3:0] buttons, // assign values in top_processor, 4 bits for 4 buttons
    output logic irq,
    output logic [3:0] interrupt_id // assume for now 4 buttons
);
    
    localparam int DEBOUNCER_CLK_CYCLES = 1000;
    int but0_clk_count = 0;
    int but1_clk_count = 0;
    int but2_clk_count = 0;
    int but3_clk_count = 0;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            irq <= 1'b0;
            interrupt_id <= 4'b0;
            but0_clk_count <= 0;
            but1_clk_count <= 0;
            but2_clk_count <= 0;
            but3_clk_count <= 0;
        end
        // interrupt_pending already taken care of in interrupt_handling, this module just raises an interrupt
        // whether accepted depends on if already processing an interrupt

        // error when assign default value at top and then override in logic, Quartus thinks combinational
        else begin
            if (buttons != 4'b000) begin
                if (buttons[0]) begin
                    if (but0_clk_count == DEBOUNCER_CLK_CYCLES - 1) begin
                        interrupt_id <= 4'b0001; // better assigna s a whole vector and not bit by bit,
                                                // Quartus gets confused as it thinks you are overriding register
                        but0_clk_count <= 0;
                        irq <= 1'b1;
                    end
                    else begin
                        interrupt_id <= 4'b0;
                        but0_clk_count <= but0_clk_count + 1;
                    end
                end
                else if (buttons[1]) begin
                    if (but1_clk_count == DEBOUNCER_CLK_CYCLES - 1) begin
                        interrupt_id <= 4'b0010;
                        but1_clk_count <= 0;
                        irq <= 1'b1;
                    end
                    else begin
                        interrupt_id <= 4'b0;
                        but1_clk_count <= but1_clk_count + 1;
                    end
                end
                else
                    interrupt_id <= 4'b0;

                but2_clk_count <= 0; // unassigned for now
                but3_clk_count <= 0;
            end
            else begin
                interrupt_id <= 4'b0;
                but0_clk_count <= 0;
                but1_clk_count <= 0;
                but2_clk_count <= 0;
                but3_clk_count <= 0;
            end

            if (iack)
                irq <= 1'b0;
        end
    end

endmodule
