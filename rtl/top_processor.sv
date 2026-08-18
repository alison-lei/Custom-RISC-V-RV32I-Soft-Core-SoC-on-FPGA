`timescale 1ns / 1ns

// TODO:
// figure out the swap bit, cpu_done register, also have lcd_done from lcd_controller
// configure the memory sizes of instructions, dataram, interrupts, and sram


module top_processor (
    input logic clk, reset,
    input logic [3:0] KEY, // for buttons
    output logic [31:0] last_reg_data,

    output logic [19:0] SRAM_ADDR,
    inout logic [15:0] SRAM_DQ,
    output logic SRAM_UB_N, SRAM_LB_N, SRAM_CE_N, SRAM_OE_N, SRAM_WE_N,

    output logic sclk, lcd_cs, lcd_dc, lcd_mosi
);
    // update_pc
    logic branch_b, jump_b;
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
    logic jump_enable, branch_enable, load_enable, store_enable, rd_enable, ALUSrc, use_pc;
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

    assign logic [3:0] buttons = ~KEY;
    

    // lcd_controller and sram_controller
    logic cpu_we;
    logic cpu_done;
    logic lcd_done;
    logic swap_bit;
    logic spi_sram_sel;
    logic [15:0] lcd_rdata;
    logic [19:0] lcd_sram_addr, lcd_buffer_base_addr;
    


    // memory_stage
    logic [31:0] mem_stage_rd_data;

    // writeback is technically just 1 assign statement to determine between execute value or ram


    // implement Harvard architecture as fetch and peripherals access memory at different timlocations
    // they use separate busses so there is no interference, can read instruction and write data to block RAM at same time
    // synchronous on pos clock edge
    update_pc pc0 (.clk(clk), .reset(reset), .branch_b(branch_b), .jump_b(jump_b), .mret_enable(mret_enable), .mtvec_enable(mtvec_enable),
                    .branch_addr(branch_addr), .jump_addr(jump_addr), .mepc(mepc), .mtvec(mtvec), .out_pc(current_pc));
    
    bus b0 (.reset(reset), .addr(mem_addr), .dataram_sel(dataram_sel), .interrupt_sel(interrupt_sel),
            .target_mem_index(target_mem_index));

    // can write current_pc as it will never go past the instruction partition in memory/surpass 32'h00000FFF
    fetch f0 (.addr(current_pc), .instr(instr));

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
                    .mem_addr(target_mem_index), .dataram_read_data(dataram_read_data));
    
    gpio_master gpio0 (.clk(clk), .reset(reset), .iack(iack), .buttons(buttons), .irq(irq), .interrupt_id(interrupt_id));

    interrupt_handler intrpt_hndlr0 (.clk(clk), .reset(reset), .irq(irq), .iack(iack), .interrupt_sel(interrupt_sel),
                                    .interrupt_id(interrupt_id), .mstatus(mstatus), .mie(mie), .interrupt_mem_addr(target_mem_index),
                                    .mtvec_enable(mtvec_enable), .interrupt_pending(interrupt_pending), .interrupt_read_data(interrupt_read_data));
    
    lcd_controller lcd_contr (.clk(clk), .reset(reset), .spi_sram_sel(spi_sram_sel), .buffer_base_addr(lcd_buffer_base_addr), .sram_data(lcd_rdata),
                                .lcd_done(lcd_done), .lcd_dc(lcd_dc), .sram_addr(lcd_sram_addr), .sclk(sclk), .lcd_cs(lcd_cs), .lcd_mosi(lcd_mosi));

                                                                                                    // load the last 16 bits
    sram_controller sram_contr (.cpu_we(cpu_we), .cpu_sram_addr(target_mem_index), .lcd_sram_addr(lcd_sram_addr), .cpu_wdata(rs2_data[0 +: 16]), .lcd_rdata(lcd_rdata),
                                .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_UB_N(SRAM_UB_N), .SRAM_LB_N(SRAM_LB_N), .SRAM_CE_N(SRAM_CE_N),
                                .SRAM_OE_N(SRAM_OE_N), .SRAM_WE_N(SRAM_WE_N));

    // each peripheral outputs its own read_data wire and memory_stage picks the correct one
    memory_stage memstge0 (.ld_enable(load_enable), .dataram_sel(dataram_sel), .interrupt_sel(interrupt_sel), .dataram_read_data(dataram_read_data),
                            .interrupt_read_data(interrupt_read_data), .load_reg_data(mem_stage_rd_data));

    writeback wb0 (.ld_enable(load_enable), .ex_final_reg_data(execute_rd_data), .mem_load_reg_data(mem_stage_rd_data),
                    .last_reg_data(last_reg_data));


    always_comb begin
        csr_read_data = 32'b0;
        cpu_we = 1'b0;

        case (csr_addr)
            12'h300 : csr_read_data = mstatus;
            12'h304 : csr_read_data = mie;
            12'h305 : csr_read_data = mtvec;
            12'h341 : csr_read_data = mepc;
            12'h342 : csr_read_data = mcause;
        endcase

        // ensures no latency as lcd_controller needs correct base addr when spi_sram_sel is high
        lcd_buffer_base_addr <= (swap_bit) ? 20'h06000 : 20'h2D100;

        if (store_enable) begin
            if (swap_bit) begin
                if (mem_addr >= 32'h0002D100 && mem_addr < 32'h0009F200)
                    cpu_we = 1'b1;
            end else begin
                if (mem_addr >= 32'h00006000 && mem_addr < 32'h0002D100)
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
            csr_write_data <= 32'b0;
            // swap_bit = 0 means cpu write in A and lcd read in B
            // swap_bit = 1 means cpu write in B and lcd read in A
            swap_bit <= 1'b0;
            lcd_done <= 1'b1;
            cpu_done <= 1'b1;
        end
        else if (mtvec_enable) begin
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
            endcase
        end

        // cpu writes to address 0x1200 to signal done writing to a framebuffer
        if (mem_addr == 32'h1200 && store_enable)
            cpu_done <= 1'b1;

        if (lcd_done && cpu_done) begin
            cpu_done <= 1'b0;
            lcd_done <= 1'b0;
            swap_bit <= ~swap_bit;
            spi_sram_sel <= 1'b1; // spi_sram_sel tells it when the framebuffers were switched and so
                                  // now lcd has a newly written buffer to read and so another frame should be sent
        end
        else
            spi_sram_sel <= 1'b0;
        
    end

endmodule

