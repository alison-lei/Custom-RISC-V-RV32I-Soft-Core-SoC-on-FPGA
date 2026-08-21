`timescale 1ns / 1ns

// have 2 framebuffers
// need a swap variable, frame done signal from software
// only change swap value when cpu done writing frame of 1 buffer,
// and lcd done sending data of other buffer over spi to display

// assume this module is fed in the correct base address of the correct buffer based on swap

// hardware is 16 bits per SRAM address, but RISC-V 32 is store word as 32 bits, so just store as half word 
// have spi_controller send bytes as ILI9341 expects bytes on the wire

module lcd_controller (
    input logic clk, reset, spi_sram_sel,
    input logic [19:0] buffer_base_addr, // is 20 bits
    input logic [15:0] sram_data, // value of that specific pixel
    output logic lcd_done, init_done, lcd_dc,
    output logic [19:0] sram_addr, // address of specific pixel
    output logic sclk, lcd_cs, lcd_mosi
);
    // math:
    // 240x320 display, 76800 pixels worth of data must be sent over spi per frame
    // so that is 153600 bytes of data
    // each spi send is programmed to be 16 bits or 2 bytes

    localparam int CYCLES_PER_MS = 50000; // 50,000 cycles per ms
    localparam int SYSTEM_CYCLES_PER_SCLK = 10; 
    // localparam int TOTAL_PIXELS = 76800;
    // localparam int TOTAL_INIT_COMMANDS = 18;
    // localparam int TOTAL_FRAME_COMMANDS = 11;
    localparam int TOTAL_PIXELS = 10;
    localparam int TOTAL_INIT_COMMANDS = 3;
    localparam int TOTAL_FRAME_COMMANDS = 2;
    int counter = 0;

    typedef enum logic [3:0] {
        INITIAL = 4'd0, // here, run through all the ROM commands
        WAIT_START = 4'd1,
        INITIAL_WAIT = 4'd2,
        DELAY = 4'd3,
        IDLE = 4'd4,
        FRAME_CONFIG = 4'd5,
        FRAME_WAIT = 4'd6,
        SEND_HIGH_BYTE = 4'd7,
        WAIT = 4'd8,
        SEND_LOW_BYTE = 4'd9,
        STOP = 4'd10
    } state_type;
    
    // packed tells synthesizer to treat variables in struct as a single bit vector rather than multiple variables, important for hardware
    typedef struct packed {
        logic is_command; // if 1 then is command and so lcd_dc = 0
        logic [7:0] byte_val;
        logic [7:0] delay_ms;
    } init_com_data;

    typedef struct packed {
        logic is_command;
        logic [7:0] byte_val;
    } init_frame_config;

    // initialize ROM, array of structs
    init_com_data init_rom [0:17];
    init_frame_config init_frame [0:10];

    initial begin
        // software reset
        init_rom[0].is_command = 1'b1;
        init_rom[0].byte_val = 8'h01;
        // init_rom[0].delay_ms = 8'd150;
        init_rom[0].delay_ms = 8'd0;

        // power control B
        init_rom[1].is_command = 1'b1;
        init_rom[1].byte_val = 8'hCF;
        init_rom[1].delay_ms = 8'b0;

        init_rom[2].is_command = 1'b0;
        init_rom[2].byte_val = 8'b0;
        init_rom[2].delay_ms = 8'b0;

        init_rom[3].is_command = 1'b0;
        init_rom[3].byte_val = 8'h83;
        init_rom[3].delay_ms = 8'b0;
        
        init_rom[4].is_command = 1'b0;
        init_rom[4].byte_val = 8'h30;
        init_rom[4].delay_ms = 8'b0;

        // power on sequence
        init_rom[5].is_command = 1'b1;
        init_rom[5].byte_val = 8'hED;
        init_rom[5].delay_ms = 8'b0;

        init_rom[6].is_command = 1'b0;
        init_rom[6].byte_val = 8'h64;
        init_rom[6].delay_ms = 8'b0;

        init_rom[7].is_command = 1'b0;
        init_rom[7].byte_val = 8'h03;
        init_rom[7].delay_ms = 8'b0;
        
        init_rom[8].is_command = 1'b0;
        init_rom[8].byte_val = 8'h12;
        init_rom[8].delay_ms = 8'b0;

        init_rom[9].is_command = 1'b0;
        init_rom[9].byte_val = 8'h81;
        init_rom[9].delay_ms = 8'b0;

        // power control 1
        init_rom[10].is_command = 1'b1;
        init_rom[10].byte_val = 8'hC0;
        init_rom[10].delay_ms = 8'b0;

        init_rom[11].is_command = 1'b0;
        init_rom[11].byte_val = 8'h23;
        init_rom[11].delay_ms = 8'b0;

        // power control 2
        init_rom[12].is_command = 1'b1;
        init_rom[12].byte_val = 8'hC1;
        init_rom[12].delay_ms = 8'b0;

        init_rom[13].is_command = 1'b0;
        init_rom[13].byte_val = 8'h10;
        init_rom[13].delay_ms = 8'b0;

        // pixel format
        init_rom[14].is_command = 1'b1;
        init_rom[14].byte_val = 8'h3A;
        init_rom[14].delay_ms = 8'b0;

        init_rom[15].is_command = 1'b0;
        init_rom[15].byte_val = 8'h55;
        init_rom[15].delay_ms = 8'b0;

        // wake up
        init_rom[16].is_command = 1'b1;
        init_rom[16].byte_val = 8'h11;
        // init_rom[16].delay_ms = 8'd120;
        init_rom[16].delay_ms = 8'd0;

        // display on
        init_rom[17].is_command = 1'b1;
        init_rom[17].byte_val = 8'h29;
        init_rom[17].delay_ms = 8'b0;

        // initialize the frame configuration
        //set column length
        init_frame[0].is_command = 1'b1;
        init_frame[0].byte_val = 8'h2A;

        init_frame[1].is_command = 1'b0;
        init_frame[1].byte_val = 8'b0;

        init_frame[2].is_command = 1'b0;
        init_frame[2].byte_val = 8'b0;

        init_frame[3].is_command = 1'b0;
        init_frame[3].byte_val = 8'b0;

        init_frame[4].is_command = 1'b0;
        init_frame[4].byte_val = 8'hEF;

        // set row length
        init_frame[5].is_command = 1'b1;
        init_frame[5].byte_val = 8'h2B;
        
        init_frame[6].is_command = 1'b0;
        init_frame[6].byte_val = 8'b0;

        init_frame[7].is_command = 1'b0;
        init_frame[7].byte_val = 8'b0;

        init_frame[8].is_command = 1'b0;
        init_frame[8].byte_val = 8'h01;

        init_frame[9].is_command = 1'b0;
        init_frame[9].byte_val = 8'h3F;

        // signal that now write to memory, pixel stream follows immediately
        init_frame[10].is_command = 1'b1;
        init_frame[10].byte_val = 8'h2C;

    end

    int init_rom_index = 0;
    int init_frame_index = 0;
    int delay_amt;
    int delay_counter = 0;
    int start_counter = 0;

    logic spi_done;
    logic [15:0] pixel_data;
    logic [7:0] byte_data = 8'b0;

    state_type state = INITIAL;
    state_type next_state = IDLE;
    logic start = 1'b0;

    // when DC (Data/Command) is low then command, high then the byte is pixel data
    // use this to send both command and data bytes
    spi_controller spi0 (.clk(clk), .reset(reset), .start(start), .spi_data(byte_data),
                        .sclk(sclk), .cs(lcd_cs), .mosi_data_bit(lcd_mosi), .done(spi_done));


    always_ff @(posedge clk or posedge reset) begin
        lcd_done <= 1'b0;
        start <= 1'b0;
        lcd_dc <= 1'b1; // send pixel data byte

        if (reset) begin
            state <= INITIAL;
            init_done <= 1'b0;
            counter <= 0;
        end
        else begin
            case (state)
                INITIAL : begin
                    lcd_dc <= (init_rom[init_rom_index].is_command == 1'b1) ? 1'b0 : 1'b1;
                    byte_data <= init_rom[init_rom_index].byte_val;
                    start <= 1'b1;
                    state <= WAIT_START;
                    next_state <= INITIAL_WAIT;
                    init_done <= 1'b0;
                end
                // because sclk is slower, might not detect start signal
                WAIT_START : begin
                    if (start_counter == SYSTEM_CYCLES_PER_SCLK - 1) begin
                        state <= next_state;
                        start_counter <= 0;  
                    end
                    else begin
                        start <= 1'b1;
                        start_counter <= start_counter + 1;
                    end
                end
                INITIAL_WAIT : begin
                    lcd_dc <= (init_rom[init_rom_index].is_command == 1'b1) ? 1'b0 : 1'b1;
                    byte_data <= init_rom[init_rom_index].byte_val;

                    if (spi_done) begin
                        if (init_rom[init_rom_index].delay_ms != 8'b0) begin
                            delay_amt <= init_rom[init_rom_index].delay_ms * CYCLES_PER_MS;
                            delay_counter <= 0;
                            state <= DELAY;
                            next_state <= (init_rom_index == TOTAL_INIT_COMMANDS - 1) ? IDLE : INITIAL;
                        end
                        // no need to set init_rom_index back to 0 as this only runs once in the beginning
                        else if (init_rom_index == TOTAL_INIT_COMMANDS - 1) begin
                            state <= IDLE;
                            init_done <= 1'b1;
                        end
                        else begin
                            init_rom_index <= init_rom_index + 1;    
                            state <= INITIAL;
                        end
                    end
                end
                
                DELAY : begin
                    if (delay_counter == delay_amt - 1) begin
                        state <= next_state;
                        init_rom_index <= init_rom_index + 1;
                    end
                    else
                        delay_counter <= delay_counter + 1;
                end
                IDLE : begin
                    sram_addr <= buffer_base_addr + counter;
                    state <= (spi_sram_sel) ? FRAME_CONFIG : IDLE;
                    next_state <= (spi_sram_sel) ? SEND_HIGH_BYTE : FRAME_CONFIG;
                    
                end
                FRAME_CONFIG : begin
                    lcd_dc <= (init_frame[init_frame_index].is_command) ? 1'b0 : 1'b1;
                    byte_data <= init_frame[init_frame_index].byte_val;
                    start <= 1'b1;
                    state <= WAIT_START;
                    next_state <= FRAME_WAIT;

                end
                FRAME_WAIT : begin
                    lcd_dc <= (init_frame[init_frame_index].is_command) ? 1'b0 : 1'b1;
                    byte_data <= init_frame[init_frame_index].byte_val;

                    if (spi_done) begin
                        // need to set init_frame_index back to 0 as this runs every frame
                        if (init_frame_index == TOTAL_FRAME_COMMANDS - 1) begin
                            init_frame_index <= 0;
                            state <= SEND_HIGH_BYTE;
                        end
                        else begin
                            init_frame_index <= init_frame_index + 1;
                            state <= FRAME_CONFIG;
                        end
                    end
                end
                SEND_HIGH_BYTE : begin
                    pixel_data <= sram_data;
                    byte_data <= sram_data >> 8; // must be sram_data and not pixel_data as before
                                                // pixel_data is not initialized so it doesn't get new
                                                // value of pixel_data which is sram_data, it gets xxxxxx
                    state <= WAIT;
                    next_state <= SEND_LOW_BYTE;
                    start <= 1'b1;
                end
                WAIT : begin
                    if (start_counter == SYSTEM_CYCLES_PER_SCLK - 1) begin
                        state <= (spi_done) ? next_state : WAIT;
                        start_counter <= (spi_done) ? 0 : start_counter;  
                    end
                    else begin
                        start <= 1'b1;
                        start_counter <= start_counter + 1;
                    end
                end
                SEND_LOW_BYTE : begin
                    byte_data <= pixel_data & 8'hFF;
                    state <= WAIT;
                    next_state <= STOP;
                    start <= 1'b1;
                end
                STOP : begin                    
                    if (counter == TOTAL_PIXELS - 1) begin
                        lcd_done <= 1'b1;
                        counter <= 0;
                        state <= IDLE;
                        next_state <= FRAME_CONFIG;
                    end
                    else begin
                        counter <= counter + 1;
                        state <= SEND_HIGH_BYTE;
                        sram_addr <= buffer_base_addr + counter + 1; // remember, counter in this line is the old counter value
                                                                     // so manually add 1 so sram_data can be calculated correctly
                                                                     // on next posedge
                    end
                end
                default : ;

            endcase
        end    
    end

endmodule
