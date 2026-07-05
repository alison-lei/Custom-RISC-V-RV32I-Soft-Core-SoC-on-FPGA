`timescale 1ns / 1ns

module execute (
    input logic [3:0] ALU_ctrl,
    input logic [4:0] rd_num, rs2_num,
    input logic [31:0] immediate, in_pc, rs1_data, rs2_data,
    input logic jump_enable, branch_enable, load_enable, store_enable, rd_enable, ALUSrc, use_pc,
    input logic [2:0] size, branch_type,
    
    output logic [31:0] ex_reg_data, mem_addr, branch_addr, jump_addr,
    output logic [4:0] ex_reg_num,
    output logic branch_b, jump_b
);
    typedef enum logic [3:0] {
                            ADD = 4'd0,
                            SUB = 4'd1,
                            AND = 4'd2,
                            OR = 4'd3,
                            XOR = 4'd4,
                            SLL = 4'd5,
                            SRL = 4'd6,
                            SRA = 4'd7,
                            SLT = 4'd8,
                            SLTU = 4'd9,
                            PASS = 4'd10
    } operation_type;

    typedef enum logic [2:0] {
                            BEQ = 3'b000,
                            BNE = 3'b001,
                            BLT = 3'b100,
                            BGE = 3'b101,
                            BLTU = 3'b110,
                            BGEU = 3'b111
    } branch_label;
    
    logic [31:0] operand2;

    always_comb begin
        operand2 = ALUSrc ? immediate : rs2_data;

        ex_reg_num = 5'b0;
        if (rd_enable)
            ex_reg_num = rd_num;

        ex_reg_data = 32'b0;
        mem_addr = 32'b0;
        branch_b = 1'b0;
        branch_addr = 32'b0;
        jump_b = 1'b0;
        jump_addr = 32'b0;

        case (operation_type'(ALU_ctrl))
            ADD : ex_reg_data = rs1_data + operand2;
            SUB : ex_reg_data = rs1_data - operand2;
            AND : ex_reg_data = rs1_data & operand2;
            OR : ex_reg_data = rs1_data | operand2;
            XOR : ex_reg_data = rs1_data ^ operand2;
            SLL : ex_reg_data = rs1_data << operand2[4:0];
            SRL : ex_reg_data = rs1_data >> operand2[4:0];
            SRA : ex_reg_data = $signed(rs1_data) >>> operand2[4:0];
            SLT : ex_reg_data = $signed(rs1_data) < $signed(operand2) ? 32'b1 : 32'b0;
            SLTU : ex_reg_data = $unsigned(rs1_data) < $unsigned(operand2) ? 32'b1 : 32'b0;
            PASS : ex_reg_data = immediate;

        endcase

        // branch
        // immediate value is the signed PC-relative branch offset
        // caveat, can be a branch instruction, but the branch condition is not satisfied
        if (branch_enable) begin
            branch_addr = in_pc + $signed(immediate);

            case (branch_label'(branch_type))
                BEQ : branch_b = ex_reg_data == 32'b0 ? 1'b1 : 1'b0;
                BNE : branch_b = ex_reg_data != 32'b0 ? 1'b1 : 1'b0;
                BLT : branch_b = ex_reg_data == 32'b1 ? 1'b1 : 1'b0;
                BGE : branch_b = ex_reg_data == 32'b0 ? 1'b1 : 1'b0;
                BLTU : branch_b = ex_reg_data == 32'b1 ? 1'b1 : 1'b0;
                BGEU : branch_b = ex_reg_data == 32'b0 ? 1'b1 : 1'b0;
            endcase
        end

        // jump
        if (jump_enable) begin
            jump_b = 1'b1;
            ex_reg_data = in_pc + 32'b00000100; // ra the return address
            jump_addr = use_pc ? in_pc + immediate : (rs1_data + immediate) & ~1;
            
        end
        else begin
            if (use_pc) begin
                ex_reg_data = ex_reg_data + in_pc; // AUIPC
            end
         end

        if (load_enable || store_enable)
            mem_addr = rs1_data + immediate;
            
    end

endmodule