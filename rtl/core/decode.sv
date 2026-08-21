`timescale 1ns / 1ns

module decode (
    input logic [31:0] instr,
    output logic [3:0] ALU_ctrl,
    output logic [4:0] rd_num, rs1_num, rs2_num,
    output logic [31:0] immediate,
    output logic [11:0] csr_addr,
    // can be jump and branch instructions (enable), but branch condition might not be satisfied (not _b)
    output logic jump_enable, branch_enable, load_enable, store_enable, rd_enable, ALUSrc, use_pc,
    output logic csr_enable, mret_enable, iack,
    output logic [2:0] size, branch_type,
    output logic [1:0] csr_operation
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

    typedef enum logic [1:0] {
                            CSRRW = 2'd1,
                            CSRRS = 2'd2,
                            CSRRC = 2'd3
    } csr_operation_type;

    typedef enum logic [2:0] {
                            BYTE = 3'b000,
                            H_WORD = 3'b001,
                            WORD = 3'b010,
                            BYTE_U = 3'b011,
                            H_WORD_U = 3'b100
    } st_ld_size;

    logic [31:0] imm;
    logic [6:0]  funct7;
    logic [4:0]  rs2;
    logic [4:0]  rs1;
    logic [2:0]  funct3;
    logic [4:0]  rd;
    logic [6:0] opcode;

    // set it to r-type for now?
    assign opcode = instr[6:0];
    assign funct7 = instr[31:25];
    assign rs2 = instr[24:20];
    assign rs1 = instr[19:15];
    assign funct3 = instr[14:12];
    assign rd = instr[11:7];
    assign csr_addr = instr[31:20];

    always_comb begin
        immediate = 32'b0;
        rd_num = 5'b0;
        rs1_num = 5'b0;
        rs2_num = 5'b0;
        jump_enable = 1'b0;
        branch_enable = 1'b0;
        rd_enable = 1'b0;
        store_enable = 1'b0;
        load_enable = 1'b0;
        branch_type = 3'b0;
        ALUSrc = 1'b0;
        use_pc = 1'b0;
        csr_enable = 1'b0; // indicates whether the instruction is a csr instruction
        mret_enable = 1'b0; // whether is mret instruction (priviledged RISC-V instruction)
        iack = 1'b0;

        ALU_ctrl = ADD;
        csr_operation = CSRRW;
        size = BYTE;

        case (opcode)
            7'b1110011 : begin // system instructions
                csr_enable = 1'b1;
                rs1_num = rs1;
                rd_enable = 1'b1;
                rd_num = rd;
                case (funct3)
                    3'b000 : begin // if true, then is mret instruction
                        if (instr == 32'h30200073) begin
                            mret_enable = 1'b1;
                            iack = 1'b1;
                        end
                        csr_enable = 1'b0;
                        rd_enable = 1'b0;
                    end
                    3'b001 : csr_operation = CSRRW;
                    3'b010 : csr_operation = CSRRS;
                    3'b011 : csr_operation = CSRRC;
                    default : ;
                endcase
            end
            7'b0110011 : begin // R-type
                case (funct3)
                    3'b000 : begin
                        if (funct7 == 7'b0)
                            ALU_ctrl = ADD;
                        else
                            ALU_ctrl = SUB;
                    end
                    3'b001 : ALU_ctrl = SLL;
                    3'b010 : ALU_ctrl = SLT;
                    3'b011 : ALU_ctrl = SLTU;
                    3'b100 : ALU_ctrl = XOR;
                    3'b101 : begin
                        if (funct7 == 7'b0)
                            ALU_ctrl = SRL;
                        else
                            ALU_ctrl = SRA;
                    end
                    3'b110 : ALU_ctrl = OR;
                    3'b111 : ALU_ctrl = AND;
                    default : ;
                endcase

                rd_enable = 1'b1;
                rs1_num = rs1;
                rs2_num = rs2;
                rd_num = rd;

            end
            7'b0010011 : begin // I-type addi, slli
                immediate = {{20{instr[31]}}, instr[31:20]};

                case (funct3)
                    3'b000 : ALU_ctrl = ADD;
                    3'b010 : ALU_ctrl = SLT;
                    3'b011 : ALU_ctrl = SLTU;
                    3'b100 : ALU_ctrl = XOR;
                    3'b110 : ALU_ctrl = OR;
                    3'b111 : ALU_ctrl = AND;
                    3'b001 : ALU_ctrl = SLL;
                    3'b101 : begin
                        if (funct7 == 7'b0)
                            ALU_ctrl = SRL;
                        else if (funct7 == 7'b0100000) begin
                            ALU_ctrl = SRA;
                            immediate = {{27{instr[31]}}, instr[24:20]};
                        end
                    end
                    default : ;
                endcase

                rd_enable = 1'b1;
                ALUSrc = 1'b1;
                rs1_num = rs1;
                rd_num = rd;
                
            end
            7'b0100011 : begin // S-type sw, sb
                // rs1 = register containing base address
                // rs2 = register containing data that needs to be stored
                // immediate = offset to base address that gives the target address

                immediate = {{20{instr[31]}}, instr[31:25], instr[11:7]};

                ALU_ctrl = ADD;
    
                case (funct3)
                    3'b000 : size = BYTE;
                    3'b001 : size = H_WORD;
                    3'b010 : size = WORD;
                    default : ;
                endcase
                
                store_enable = 1'b1;
                ALUSrc = 1'b1;
                rs1_num = rs1;
                rs2_num = rs2;

            end
            7'b0000011 : begin // L-type lw, lb
                immediate = {{20{instr[31]}}, instr[31:20]};

                ALU_ctrl = ADD;
    
                case (funct3)
                    3'b000 : size = BYTE;
                    3'b001 : size = H_WORD;
                    3'b010 : size = WORD;
                    3'b100 : size = BYTE_U;
                    3'b101 : size = H_WORD_U;
                    default : ;
                endcase

                load_enable = 1'b1;
                rd_enable = 1'b1;
                ALUSrc = 1'b1;
                rs1_num = rs1;
                rd_num = rd;
                
            end
            7'b1100011 : begin // B-type beq, bne
                immediate = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8] , 1'b0};

                case (funct3)
                    3'b000 : ALU_ctrl = XOR; // check if the xor result is perfectly 0, then is equal, beq
                    3'b001 : ALU_ctrl = XOR; // if xor is not 0, then not perfectly equal, bne
                    3'b100 : ALU_ctrl = SLT; // if get 1, then is less than, blt
                    3'b101 : ALU_ctrl = SLT; // if get 0, then is greater or equal, bge
                    3'b110 : ALU_ctrl = SLTU; // bltu
                    3'b111 : ALU_ctrl = SLTU; // bgeu
                    default : ;
                endcase

                rs1_num = rs1;
                rs2_num = rs2;
                branch_enable = 1'b1;
                branch_type = funct3;
            end
            7'b0110111 : begin // U-type lui
                immediate = {instr[31:12], {12'b0}}; 
                ALU_ctrl = PASS;
                ALUSrc = 1'b1;
                rd_num = rd;
                rd_enable = 1'b1;

            end
            7'b0010111 : begin // U-type auipc, add upper immediate to pc
                immediate = {instr[31:12], {12'b0}}; 

                ALU_ctrl = PASS;

                use_pc = 1'b1;
                ALUSrc = 1'b1;
                rd_num = rd;
                rd_enable = 1'b1;
            end
            // Difference: JALR compute absolute address from register whereas JAL compute PC-relative address
            7'b1101111 : begin // J-type jal
                immediate = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
                
                // this lets it know that this is a jump instruction, and so rd contains PC+4 not ALU output
                jump_enable = 1'b1;
                use_pc = 1'b1;
                ALUSrc = 1'b1;
                rd_enable = 1'b1;
                rd_num = rd;
            end
            7'b1100111 : begin // I-type jalr
                immediate = {{20{instr[31]}}, instr[31:20]};
                
                jump_enable = 1'b1;
                ALUSrc = 1'b1;
                rd_enable = 1'b1;
                rs1_num = rs1;
                rd_num = rd;
            end
            default : ; // do nothing
        endcase
    end 
    
endmodule
