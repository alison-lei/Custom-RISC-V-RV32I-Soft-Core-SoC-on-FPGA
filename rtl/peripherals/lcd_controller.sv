`timescale 1ns / 1ns

// have 2 framebuffers
// need a swap variable, frame done signal from software
// only change swap value when cpu done writing frame of 1 buffer,
// and lcd done sending data of other buffer over spi to display

// assume this module is fed in the correct base address of the correct buffer based on swap

// hardware is 16 bits per SRAM address, but RISC-V 32 is store word as 32 bits, so just store as half word 
// have spi_controller send bytes as ILI9341 expects bytes on the wire

module lcd_controller (
    input logic clk, reset, spi_sram_sel
    input logic [17:0] buffer_base_addr,
    input logic [15:0] sram_data,
    output logic lcd_done,
    output logic [17:0] sram_addr
);
    // math:
    // 240x320 display, 76800 pixels worth of data must be sent over spi per frame
    // so that is 153600 bytes of data
    // each spi send is programmed to be 16 bits or 2 bytes

    localparam int TOTAL_PIXELS = 76800;
    int counter = 0;

    typedef enum logic [2:0] {
                            IDLE = 3'b000,
                            SEND_HIGH_BYTE = 3'b001,
                            WAIT_HIGH = 3'b010,
                            SEND_LOW_BYTE = 3'b011,
                            WAIT_LOW = 3'b100,
                            STOP = 3'b101
    } state_type;

    logic spi_done;
    logic [15:0] pixel_data;
    logic [7:0] byte_data = 8'b0;

    state_type state = IDLE;
    logic start = 1'b0;

    spi_controller spi0 (.clk(clk), .reset(reset), .start(start), .pixel_data(byte_data), .done(spi_done));

    always_ff @(posedge clk or posedge reset) begin
        lcd_done <= 1'b0;
        start <= 1'b0;
        byte_data <= 8'b0;

        if (reset) begin
            state <= IDLE;
            counter <= 0;
        end
        else begin
            case (state)
                IDLE : begin
                    sram_addr <= buffer_base_addr + counter;
                    state <= (spi_sram_sel == 1'b1) ? SEND_HIGH_BYTE : IDLE;
                end
                SEND_HIGH_BYTE : begin
                    pixel_data <= sram_data;
                    byte_data <= sram_data >> 8;
                    state <= WAIT_HIGH;
                    start <= 1'b1;
                end
                WAIT_HIGH : state <= spi_done ? SEND_LOW_BYTE : WAIT_HIGH;
                SEND_LOW_BYTE : begin
                    byte_data <= pixel_data & 8'hFF;
                    state <= WAIT_LOW;
                    start <= 1'b1;
                end
                WAIT_LOW : state <= spi_done ? STOP : WAIT_LOW;
                STOP : begin
                    counter <= counter + 1;
                    state <= IDLE;
                    if (counter == TOTAL_PIXELS) begin
                        lcd_done <= 1'b1;
                        counter <= 0;
                    end
                end
                default : ;

            endcase
        end    
    end

endmodule
