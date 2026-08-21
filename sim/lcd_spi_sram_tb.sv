`timescale 1ns / 1ns

module lcd_spi_sram_tb;

    // clock and reset
    logic clk, reset;
    
    // lcd_controller ports
    logic spi_sram_sel;
    logic [19:0] buffer_base_addr;
    logic [15:0] sram_data;
    logic lcd_done, init_done, lcd_dc;
    logic [19:0] sram_addr;
    
    // spi signals
    logic sclk, lcd_cs, lcd_mosi;
    
    // sram_controller ports
    logic cpu_we;
    logic [31:0] cpu_sram_addr;
    logic [15:0] cpu_wdata;
    logic [15:0] lcd_rdata;
    logic [19:0] SRAM_ADDR;
    wire  [15:0] SRAM_DQ;
    logic SRAM_WE_N, SRAM_OE_N, SRAM_CE_N, SRAM_UB_N, SRAM_LB_N;

    // swap logic signals
    logic swap_bit;
    logic cpu_done;

    // ----------------------------------------
    // simple SRAM behavioral model
    // ----------------------------------------
    logic [15:0] sim_sram [0:262143]; // 2MB / 2 bytes per address


    assign SRAM_DQ = (!SRAM_OE_N && !SRAM_CE_N && SRAM_WE_N) ?
                      sim_sram[SRAM_ADDR] : 16'hzzzz;

    always @(negedge SRAM_WE_N)  // capture on rising edge when write completes
        if (!SRAM_CE_N)
            sim_sram[SRAM_ADDR] = cpu_wdata;
    // ----------------------------------------
    // instantiate modules
    // ----------------------------------------
    lcd_controller lcd_contr (
        .clk(clk), .reset(reset),
        .spi_sram_sel(spi_sram_sel),
        .buffer_base_addr(buffer_base_addr),
        .sram_data(lcd_rdata),
        .lcd_done(lcd_done), .init_done(init_done),
        .lcd_dc(lcd_dc),
        .sram_addr(sram_addr),
        .sclk(sclk),
        .lcd_cs(lcd_cs),
        .lcd_mosi(lcd_mosi)
    );

    sram_controller sram_contr (
        .cpu_we(cpu_we),
        .cpu_sram_addr(cpu_sram_addr),
        .lcd_sram_addr(sram_addr),
        .cpu_wdata(cpu_wdata),
        .lcd_rdata(lcd_rdata),
        .SRAM_ADDR(SRAM_ADDR),
        .SRAM_DQ(SRAM_DQ),
        .SRAM_WE_N(SRAM_WE_N),
        .SRAM_OE_N(SRAM_OE_N),
        .SRAM_CE_N(SRAM_CE_N),
        .SRAM_UB_N(SRAM_UB_N),
        .SRAM_LB_N(SRAM_LB_N)
    );

    // ----------------------------------------
    // clock generation — 50MHz = 20ns period
    // ----------------------------------------
    initial clk = 0;
    always #10 clk = ~clk;

    // ----------------------------------------
    // FILL THIS IN — cpu write task, like a function
    // ----------------------------------------
    task cpu_write(input [19:0] addr, input [15:0] data);
        // what signals do you need to drive here?
        // think: cpu_sram_addr, cpu_wdata, cpu_we
        // how long should cpu_we stay high?

        cpu_we = 1'b1;
        cpu_wdata = data;
        cpu_sram_addr = addr;
        @(posedge clk);
        @(posedge clk);
        cpu_we = 1'b0;
        @(posedge clk);
    endtask

    // ----------------------------------------
    // FILL THIS IN — main test sequence
    // ----------------------------------------
    assign buffer_base_addr = (swap_bit) ? 20'h12C00 : 20'h0;

    initial begin
        // 1. initialize all inputs
        reset = 1; spi_sram_sel = 0; cpu_we = 0;
        swap_bit = 1; cpu_done = 0;
        cpu_sram_addr = 0; cpu_wdata = 0;
        
        for (int i = 0; i < 262144; i++)
            sim_sram[i] = 16'hF800;  // initialize all to red

        // 2. release reset after a few cycles
        repeat(5) @(posedge clk);
        reset = 0;

        // 3. FILL IN — write test pattern to buffer B
        // write pixel data to buffer B addresses
        // use cpu_write task
        if (swap_bit) begin
            for (int i = buffer_base_addr; i < buffer_base_addr + 10; i++) begin
                int data;
                data = ((i / 1280) % 2 == 0) ? 16'hFFFF : 16'h07E0;
                cpu_write(i, data);        
            end
        end
        // 4. FILL IN — trigger swap
        // what signals change when swap happens?
        cpu_we = 1'b0;
        cpu_done = 1'b1;
        swap_bit = 0;
        spi_sram_sel = 1'b1;
        #6800
        spi_sram_sel = 1'b0;
        // 5. FILL IN — wait for lcd_done
        // how do you wait for an output to go high?
        @(posedge lcd_done);
        swap_bit = !swap_bit;
        spi_sram_sel = 1'b1;
        @(posedge clk);
        spi_sram_sel = 1'b0;
        cpu_done = 1'b0;
        // 6. FILL IN — verify
        // what do you check and how?
        $display("value of swap_bit is: %h", swap_bit);
        
        $finish;
    end

    // ----------------------------------------
    // FILL THIS IN — assertions
    // ----------------------------------------
    // check sclk is slower than clk
    // check lcd_dc is high during pixel streaming
    // check lcd_done pulses after 76800 pixels
    // assert property (@(posedge sclk) 
    //     (lcd_cs == 0 && init_done) |-> (lcd_dc == 1))
    // else $error("lcd_dc wrong during pixel data");

    // |-> is implication operator, if left side true, then right side must be true

endmodule