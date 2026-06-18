`timescale 1ns / 1ns

module top_processor (
    input logic clk, reset,
    logic [31:0] display_rd_data
);
    // update_pc
    logic branch_b, jump_b;
    logic [31:0] branch_addr, jump_addr;

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
    logic [31:0] rd_data;
    logic [31:0] rs1_data, rs2_data;

    // execute
    logic [31:0] execute_rd_data;
    logic [31:0] mem_addr;
    logic [4:0] execute_rd_num;

    // memory_stage
    logic [31:0] mem_stage_rd_data;
    logic [4:0] mem_stage_rd_num;

    // writeback
    logic [4:0] last_reg_num;
    logic [31:0] last_reg_data;

    // do i need to pass in the current pc into update_pc
    // synchronous on pos clock edge
    update_pc pc0 (.clk(clk), .reset(reset), .branch_b(branch_b), .jump_b(jump_b), .branch_addr(branch_addr), .jump_addr(jump_addr), .out_pc(current_pc));
    
    fetch f0 (.addr(current_pc), .instr(instr));
    
    decode d0 (.instr(instr), .ALU_ctrl(ALU_ctrl), .rd_num(rd_num), .rs1_num(rs1_num), .rs2_num(rs2_num), .immediate(immediate), 
                .jump_enable(jump_enable), .branch_enable(branch_enable), .load_enable(load_enable), .store_enable(store_enable),
                .rd_enable(rd_enable), .ALUSrc(ALUSrc), .use_pc(use_pc), .size(size), .branch_type(branch_type));
    
    // also how do we reference other files (include?)
    // destinatin register written to on next clock edge
    register_file reg_f0 (.clk(clk), .reset(reset), .rd_enable(rd_enable), .rs1_num(rs1_num), .rs2_num(rs2_num),
                            .rd_num(last_reg_num), .rd_data(last_reg_data), .rs1_data(rs1_data), .rs2_data(rs2_data));

    execute ex0 (.ALU_ctrl(ALU_ctrl), .rd_num(rd_num), .rs2_num(rs2_num), .immediate(immediate), .in_pc(current_pc),
                .rs1_data(rs1_data), .rs2_data(rs2_data), .jump_enable(jump_enable), .branch_enable(branch_enable), .load_enable(load_enable),
                .store_enable(store_enable), .rd_enable(rd_enable), .ALUSrc(ALUSrc), .use_pc(use_pc), .size(size), .branch_type(branch_type),
    /*output*/  .ex_reg_data(execute_rd_data), .mem_addr(mem_addr), .branch_addr(branch_addr), .jump_addr(jump_addr),
                .ex_reg_num(execute_rd_num), .branch_b(branch_b), .jump_b(jump_b));

    // store data written to memory on next clock edge
    memory_stage memstge0 (.clk(clk), .ld_enable(load_enable), .st_enable(store_enable), .size(size), .final_reg_num(rd_num),
                            .st_data(rs2_data), .mem_addr(mem_addr), .load_reg_data(mem_stage_rd_data), .load_reg_num(mem_stage_rd_num));

    writeback wb0 (.ld_enable(load_enable), .rd_enable(rd_enable), .ex_final_reg_num(execute_rd_num), .mem_load_reg_num(mem_stage_rd_num),
                    .ex_final_reg_data(execute_rd_data), .mem_load_reg_data(mem_stage_rd_data), .last_reg_num(last_reg_num),
                    .last_reg_data(last_reg_data));

    assign display_rd_data = last_reg_data;

endmodule
