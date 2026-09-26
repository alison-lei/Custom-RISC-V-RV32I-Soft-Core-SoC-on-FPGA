`timescale 1ns / 1ns

// TODO:
// figure out the swap bit, cpu_done register, also have lcd_done from lcd_controller
// configure the memory sizes of instructions, dataram, interrupts, and sram

// load .sof onto FPGA
// $env:PATH += ";C:\intelFPGA_lite\18.0\quartus\bin64"
// cd C:\path\to\your\project
// quartus_pgm -c USB-Blaster -m JTAG -o "p;output_files\top_processor.sof"

module top_processor (
    input logic CLOCK50,
    input logic [3:0] KEY, // for buttons
    output logic [31:0] last_reg_data,

    // output logic [19:0] SRAM_ADDR,
    // inout wire [15:0] SRAM_DQ,
    // output logic SRAM_UB_N, SRAM_LB_N, SRAM_CE_N, SRAM_OE_N, SRAM_WE_N,

    output logic sclk, lcd_cs, lcd_dc, lcd_mosi,
    output logic LEDG0, LEDG1, LEDG2, LEDG3, LEDG4, LEDG5, LEDG6

    // output logic [31:0] mem_addr, current_pc, target_mem_index, 
    // output logic cpu_done, store_enable, init_lcd_read, spi_sram_sel, swap_bit, lcd_ack, cpu_we, lcd_done, init_done
);
    logic clk;
    logic locked;
    sys_pll sys_pll_clk (.areset(areset), .inclk0(CLOCK50), .c0(clk), .locked(locked));

    wire areset = ~KEY[2];
    wire async_reset = ~KEY[2] | ~locked;

    logic [1:0] reset_sync;
    logic ledg6_reg;
    assign LEDG6 = ledg6_reg;

    always_ff @(posedge clk or posedge async_reset) begin
        if (async_reset)
            reset_sync <= 2'b11;
        else
            reset_sync <= {reset_sync[0], 1'b0}; 
    end

    wire reset = reset_sync[1];

    assign LEDG0 = locked;        // lit when PLL has locked
    assign LEDG1 = reset;         // lit while held in reset (should go LOW after lock+button release)


    typedef enum logic [1:0] {
        FETCH = 2'b0,
        EXEC = 2'b01,
        MEM_WAIT = 2'b10
    } cpu_state_types;

    cpu_state_types cpu_state;

    // update_pc
    logic branch_b, jump_b, pc_enable;
    logic [31:0] branch_addr, jump_addr;    

    // bus
    logic dataram_sel, interrupt_sel;
    logic [31:0] target_mem_index;

    // fetch
    logic [31:0] current_pc;
    logic [31:0] instr;

    // decode
    logic [3:0] ALU_ctrl;
    logic [4:0] rd_num, rs1_num, rs2_num;
    logic [31:0] immediate;
    logic store_enable;
    logic jump_enable, branch_enable, load_enable, rd_enable, ALUSrc, use_pc;
    logic [2:0] size, branch_type;

    // register_file
    logic [31:0] rs1_data, rs2_data;

    // execute
    logic [31:0] execute_rd_data;
    logic [31:0] mem_addr;

    // dataram
    logic [31:0] dataram_read_data;

    // interrupts
    // initialization of csr registers
    logic [31:0] mstatus, mie, mtvec, mepc, mcause;
    logic csr_enable, mret_enable, mtvec_enable;
    logic [31:0] csr_addr;
    logic [1:0] csr_operation;
    logic [31:0] csr_read_data, csr_write_data;
    logic irq, iack, interrupt_pending;
    logic [3:0] interrupt_id;
    logic [31:0] interrupt_read_data;

    logic [3:0] buttons;
    assign buttons = ~KEY;
    

    // lcd_controller and sram_controller
    logic cpu_we;
    logic cpu_done, lcd_done, lcd_ack, init_done, init_lcd_read;
    logic swap_bit;
    logic spi_sram_sel;
    logic [15:0] lcd_rdata;
    logic [17:0] lcd_sram_addr, lcd_buffer_base_addr;
    

    // memory_stage
    logic [31:0] mem_stage_rd_data;

    // writeback is technically just 1 assign statement to determine between execute value or ram

    initial begin
        init_lcd_read = 1'b1;
    end

    // implement Harvard architecture as fetch and peripherals access memory at different timlocations
    // they use separate busses so there is no interference, can read instruction and write data to block RAM at same time
    // synchronous on pos clock edge
    update_pc pc0 (.clk(clk), .reset(reset), .pc_enable(pc_enable), .branch_b(branch_b), .jump_b(jump_b), .mret_enable(mret_enable), .mtvec_enable(mtvec_enable),
                    .branch_addr(branch_addr), .jump_addr(jump_addr), .mepc(mepc), .mtvec(mtvec), .out_pc(current_pc));
    
    bus b0 (.reset(reset), .addr(mem_addr), .dataram_sel(dataram_sel), .interrupt_sel(interrupt_sel),
            .target_mem_index(target_mem_index));

    // can write current_pc as it will never go past the instruction partition in memory/surpass 32'h00000FFF
    fetch f0 (.clk(clk), .addr(current_pc), .instr(instr));

    // below havent changed from mem_addr to target_mem_index
    decode d0 (.instr(instr), .ALU_ctrl(ALU_ctrl), .rd_num(rd_num), .rs1_num(rs1_num), .rs2_num(rs2_num), .immediate(immediate), .csr_addr(csr_addr),
                .jump_enable(jump_enable), .branch_enable(branch_enable), .load_enable(load_enable), .store_enable(store_enable),
                .rd_enable(rd_enable), .ALUSrc(ALUSrc), .use_pc(use_pc), .csr_enable(csr_enable), .mret_enable(mret_enable), .iack(iack),
                .size(size), .branch_type(branch_type), .csr_operation(csr_operation));

    // destination register written to on next clock edge
    register_file reg_f0 (.clk(clk), .reset(reset), .rd_enable(rd_enable), .rs1_num(rs1_num), .rs2_num(rs2_num),
                            .rd_num(rd_num), .rd_data(last_reg_data), .rs1_data(rs1_data), .rs2_data(rs2_data));

    execute ex0 (.ALU_ctrl(ALU_ctrl), .rd_num(rd_num), .rs2_num(rs2_num), .immediate(immediate), .in_pc(current_pc),
                .rs1_data(rs1_data), .rs2_data(rs2_data), .jump_enable(jump_enable), .branch_enable(branch_enable), .load_enable(load_enable),
                .store_enable(store_enable), .ALUSrc(ALUSrc), .use_pc(use_pc), .size(size), .branch_type(branch_type),
                .csr_operation(csr_operation), .csr_enable(csr_enable), .csr_read_data(csr_read_data),
    /*output*/  .ex_reg_data(execute_rd_data), .mem_addr(mem_addr), .branch_addr(branch_addr), .jump_addr(jump_addr),
                .branch_b(branch_b), .jump_b(jump_b), .csr_write_data(csr_write_data));

    // store data written to memory on next clock edge and load data
    data_ram dr0 (.clk(clk), .dataram_sel(dataram_sel), .ld_enable(load_enable), .st_enable(store_enable), .size(size), .st_data(rs2_data),
                    .mem_addr(mem_addr), .dataram_read_data(dataram_read_data));
    
    gpio_master gpio0 (.clk(clk), .reset(reset), .iack(iack), .buttons(buttons), .irq(irq), .interrupt_id(interrupt_id));

    interrupt_handler intrpt_hndlr0 (.clk(clk), .reset(reset), .irq(irq), .iack(iack), .interrupt_sel(interrupt_sel),
                                    .interrupt_id(interrupt_id), .mstatus(mstatus), .mie(mie), .interrupt_mem_addr(target_mem_index),
                                    .mtvec_enable(mtvec_enable), .interrupt_pending(interrupt_pending), .interrupt_read_data(interrupt_read_data));
    
    lcd_controller lcd_contr (.clk(clk), .reset(reset), .spi_sram_sel(spi_sram_sel), .lcd_ack(lcd_ack), .buffer_base_addr(lcd_buffer_base_addr), .sram_data(lcd_rdata),
                                .lcd_done(lcd_done), .init_done(init_done), .lcd_dc(lcd_dc), .sram_addr(lcd_sram_addr), .sclk(sclk), .lcd_cs(lcd_cs), .lcd_mosi(lcd_mosi));

    framebuffer_ram_ip frmbffr_ram_ip (.clock(clk), .data(rs2_data[0 +: 16]), .rdaddress(lcd_sram_addr), .wraddress(target_mem_index[1 +: 18]), .wren(cpu_we), .q(lcd_rdata));                                                                           // load the last 16 bits
    
    // sram_controller sram_contr (.cpu_we(cpu_we), .cpu_sram_addr(target_mem_index), .lcd_sram_addr(lcd_sram_addr), .cpu_wdata(rs2_data[0 +: 16]), .lcd_rdata(lcd_rdata),
    //                             .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_UB_N(SRAM_UB_N), .SRAM_LB_N(SRAM_LB_N), .SRAM_CE_N(SRAM_CE_N),
    //                             .SRAM_OE_N(SRAM_OE_N), .SRAM_WE_N(SRAM_WE_N));

    // each peripheral outputs its own read_data wire and memory_stage picks the correct one
    memory_stage memstge0 (.ld_enable(load_enable), .dataram_sel(dataram_sel), .interrupt_sel(interrupt_sel), .dataram_read_data(dataram_read_data),
                            .interrupt_read_data(interrupt_read_data), .mem_stage_rd_data(mem_stage_rd_data));

    writeback wb0 (.ld_enable(load_enable), .ex_final_reg_data(execute_rd_data), .mem_stage_rd_data(mem_stage_rd_data),
                    .last_reg_data(last_reg_data));


    // determines whether to hold the instr const or not
    assign pc_enable = (cpu_state == EXEC && !load_enable) || (cpu_state == MEM_WAIT);
    // assign pc_enable = (cpu_state == EXEC) || (cpu_state == FETCH && (!load_enable && !store_enable)) || (cpu_state == INITIAL);

    // always_ff @(posedge clk or posedge reset) begin
    //     if (reset)
    //         cpu_state <= INITIAL;
    //     else begin
    //         case (cpu_state)
    //             INITIAL : cpu_state <= FETCH
    //             FETCH : cpu_state <= (load_enable || store_enable) ? EXEC : FETCH;
    //             EXEC : cpu_state <= FETCH;
    //             default : cpu_state <= FETCH;
    //         endcase
    //     end
    // end

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            cpu_state <= FETCH;
        else begin
            case (cpu_state)
                FETCH : cpu_state <= EXEC; // in FETCH, put in address and will get data on next clk edge, so need to wait with same pc
                EXEC : cpu_state <= (load_enable || store_enable) ? MEM_WAIT : FETCH; // SOLUTION!
                MEM_WAIT : cpu_state <= FETCH;
                default : cpu_state <= FETCH;
            endcase
        end
    end


    always_comb begin
        csr_read_data = 32'b0;
        cpu_we = 1'b0;

        case (csr_addr)
            12'h300 : csr_read_data = mstatus;
            12'h304 : csr_read_data = mie;
            12'h305 : csr_read_data = mtvec;
            12'h341 : csr_read_data = mepc;
            12'h342 : csr_read_data = mcause;
            default : ;
        endcase

        // systemverilog is unsigned logic variables by default
        // ensures no latency as lcd_controller needs correct base addr when spi_sram_sel is high
        lcd_buffer_base_addr = (swap_bit) ? 18'd0 : 18'd76800;
        // buffer A offset = 0x6000 - 0x6000 = 0
        // buffer B offset = 0x2D100 - 0x6000 = 0x27100

        if (store_enable) begin
            if (swap_bit) begin
                if (mem_addr >= 32'h0002B800 && mem_addr < 32'h00051000)
                    cpu_we = 1'b1;
            end else begin
                if (mem_addr >= 32'h00006000 && mem_addr < 32'h0002B800)
                    cpu_we = 1'b1;
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mstatus <= 32'b0;
            mie <= 32'b0;
            mtvec <= 32'b0;
            mepc <= 32'b0;
            mcause <=32'b0;
            // swap_bit = 0 means cpu write in A and lcd read in B
            // swap_bit = 1 means cpu write in B and lcd read in A
            swap_bit <= 1'b0;
            cpu_done <= 1'b0;
            init_lcd_read <= 1'b1;
            ledg6_reg <= 1'b0;
        end
        else begin
            if (mtvec_enable) begin
                mepc <= current_pc;
                mcause <= 32'h8000000B;
            end
            else if (csr_enable) begin
                case (csr_addr)
                    12'h300 : mstatus <= csr_write_data;
                    12'h304 : mie <= csr_write_data;
                    12'h305 : mtvec <= csr_write_data;
                    12'h341 : mepc <= csr_write_data;
                    12'h342 : mcause <= csr_write_data;
                    default : ;
                endcase
            end

            // cpu writes to address 0x1200 to signal done writing to a framebuffer
            if (target_mem_index == 32'h1200 && store_enable)
                cpu_done <= 1'b1;
            
            if (target_mem_index == 32'h100 && store_enable)  // 0x5100 - 0x5000 = 0x100
                ledg6_reg <= (rs2_data == 32'd1);

            if ((lcd_done && cpu_done || init_lcd_read && cpu_done) && init_done) begin
                cpu_done <= 1'b0;
                lcd_ack <= 1'b1;
                swap_bit <= ~swap_bit;
                spi_sram_sel <= 1'b1; // spi_sram_sel tells it when the framebuffers were switched and so
                                      // now lcd has a newly written buffer to read and so another frame should be sent
                init_lcd_read <= 1'b0;
            end
            else begin
                spi_sram_sel <= 1'b0;
                lcd_ack <= 1'b0;
            end
        end
    end

    assign LEDG2 = cpu_done;
    assign LEDG3 = init_lcd_read;
    assign LEDG4 = init_done;
    assign LEDG5 = lcd_done;

endmodule

