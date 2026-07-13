`timescale 1ns / 1ns

module top_processor (
    input logic clk, reset,
    input logic sw0,
    input logic butn0, butn1, butn2, butn3,
    output logic [31:0] last_reg_data
);
    // update_pc
    logic branch_b, jump_b;
    logic [31:0] branch_addr, jump_addr;

    // bus
    logic dataram_sel, gpio_sel, spi_sel, interrupt_sel;
    logic [31:0] target_mem_indx;

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
    logic [4:0] execute_rd_num;

    // RAM and peripherals
    // WTF, GPIO SEL AND READ_DATA IS USELESS?
    // no point if gpios like button and switches are hardcoded
    assign buttons = {butn3, butn2, butn1, butn0}
    logic [31:0] spi_read_data, interrupt_read_data;

    // memory_stage
    logic [31:0] mem_stage_rd_data;
    logic [4:0] mem_stage_rd_num;

    // writeback
    logic [4:0] last_reg_num;

    // implement Harvard architecture as fetch and memory state access memory at different times for different reasons
    // synchronous on pos clock edge
    update_pc pc0 (.clk(clk), .reset(reset), .branch_b(branch_b), .jump_b(jump_b), .branch_addr(branch_addr), .jump_addr(jump_addr), .out_pc(current_pc));
    
    bus b0 (.reset(reset), .addr(mem_addr), .dataram_sel(dataram_sel), .gpio_sel(gpio_sel), .spi_sel(spi_sel),
            .interrupt_sel(interrupt_sel), .target_mem_indx(target_mem_indx));

    // can write current_pc as it will never go past the instruction partition in memory/surpass 32'h00000FFF
    fetch f0 (.addr(current_pc), .instr(instr));

    // havent changed from current_pc to target_mem_index
    decode d0 (.instr(instr), .ALU_ctrl(ALU_ctrl), .rd_num(rd_num), .rs1_num(rs1_num), .rs2_num(rs2_num), .immediate(immediate), 
                .jump_enable(jump_enable), .branch_enable(branch_enable), .load_enable(load_enable), .store_enable(store_enable),
                .rd_enable(rd_enable), .ALUSrc(ALUSrc), .use_pc(use_pc), .size(size), .branch_type(branch_type));
    
    
    // destinatin register written to on next clock edge
    register_file reg_f0 (.clk(clk), .reset(reset), .rd_enable(rd_enable), .rs1_num(rs1_num), .rs2_num(rs2_num),
                            .rd_num(last_reg_num), .rd_data(last_reg_data), .rs1_data(rs1_data), .rs2_data(rs2_data));

    execute ex0 (.ALU_ctrl(ALU_ctrl), .rd_num(rd_num), .rs2_num(rs2_num), .immediate(immediate), .in_pc(current_pc),
                .rs1_data(rs1_data), .rs2_data(rs2_data), .jump_enable(jump_enable), .branch_enable(branch_enable), .load_enable(load_enable),
                .store_enable(store_enable), .rd_enable(rd_enable), .ALUSrc(ALUSrc), .use_pc(use_pc), .size(size), .branch_type(branch_type),
    /*output*/  .ex_reg_data(execute_rd_data), .mem_addr(mem_addr), .branch_addr(branch_addr), .jump_addr(jump_addr),
                .ex_reg_num(execute_rd_num), .branch_b(branch_b), .jump_b(jump_b));

    // store data written to memory on next clock edge and load data
    data_ram dr0 (.clk(clk), .dataram_sel(dataram_sel), .ld_enable(ld_enable), .st_enable(st_enable), .size(size), .st_data(rs2_data),
                    .mem_addr(target_mem_index), .dataram_read_data())
    // might get rid of all gpio_sel and gpio_read_data
    // each peripheral outputs its own read_data wire and memory_stage picks the correct one
    // this is the new one, below is old one
    memory_stage memstge0 (.ld_enable(ld_enable), .final_reg_num(rd_num), .dataram_sel(dataram_sel), .gpio_sel(gpio_sel), .spi_sel(spi_sel),
                            .interrupt_sel(interrupt_sel), .dataram_read_data(dataram_read_data), .gpio_reaad_data(gpio_read_data),
                            .spi_read_data(spi_read_data), .interrupt_read_data(interrupt_read_data), .load_reg_data(mem_stage_rd_data),
                            .load_reg_num(mem_stage_rd_num));

    memory_stage memstge0 (.clk(clk), .ld_enable(load_enable), .st_enable(store_enable), .size(size), .final_reg_num(rd_num),
                            .st_data(rs2_data), .mem_addr(target_mem_indx), .load_reg_data(mem_stage_rd_data), .load_reg_num(mem_stage_rd_num));

    writeback wb0 (.ld_enable(load_enable), .rd_enable(rd_enable), .ex_final_reg_num(execute_rd_num), .mem_load_reg_num(mem_stage_rd_num),
                    .ex_final_reg_data(execute_rd_data), .mem_load_reg_data(mem_stage_rd_data), .last_reg_num(last_reg_num),
                    .last_reg_data(last_reg_data));

endmodule

