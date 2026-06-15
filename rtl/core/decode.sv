`timescale 1ns / 1ns

/*
what's left:
- enables
- memory read and write... is that even correct?
*/


module decode (
    input logic reset,
    input logic [31:0] instr,
    output logic [3:0] ALU_ctrl,
    output logic [4:0] rd_num, rs1_num, rs2_num,
    output logic [31:0] immediate,
    output logic jump_enable, branch_enable, load_enable, store_enable, rd_enable, ALUSrc, use_pc,
    output logic [2:0] size, branch_type
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
                            BYTE = 3'b000,
                            H_WORD = 3'b001,
                            WORD = 3'b010,
                            BYTE_U = 3'b011,
                            H_WORD_U = 3'b100
    } st_ld_size;

    operation_type op;
    st_ld_size sz;

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

    always_comb begin
        op = 4'b0;
        imm = 32'b0;
        rd_num = 5'b0;
        rs1_num = 5'b0;
        rs2_num = 5'b0;
        jump_enable = 1'b0;
        branch_enable = 1'b0;
        rd_enable = 1'b0;
        store_enable = 1'b0;
        load_enable = 1'b0;
        sz = 3'b0;
        branch_type = 3'b0;
        ALUSrc = 1'b0;
        use_pc = 1'b0;

        case (opcode)
            7'b0110011 : begin // R-type
                case (funct3)
                    3'b000 : begin
                        if (funct7 == 7'b0)
                            op = ADD;
                        else
                            op = SUB;
                    end
                    3'b001 : op = SLL;
                    3'b010 : op = SLT;
                    3'b011 : op = SLTU;
                    3'b100 : op = XOR;
                    3'b101 : begin
                        if (funct7 == 7'b0)
                            op = SRL;
                        else
                            op = SRA;
                    end
                    3'b110 : op = OR;
                    3'b111 : op = AND;
                endcase

                rd_enable = 1'b1;
                rs1_num = rs1;
                rs2_num = rs2;
                rd_num = rd;

            end
            7'b0010011 : begin // I-type addi, slli, lw
                imm = {{20{instr[31]}}, instr[31:20]};

                case (funct3)
                    3'b000 : op = ADD;
                    3'b010 : op = SLT;
                    3'b011 : op = SLTU;
                    3'b100 : op = XOR;
                    3'b110 : op = OR;
                    3'b111 : op = AND;
                    3'b001 : op = SLL;
                    3'b101 : begin
                        if (funct7 == 7'b0)
                            op = SRL;
                        else if (funct7 == 7'b0100000) begin
                            op = SRA;
                            imm = {{27{instr[31]}}, instr[24:20]};
                        end
                    end
                endcase

                rd_enable = 1'b1;
                ALUSrc = 1'b1;
                rs1_num = rs1;
                rd_num = rd;
                
            end
            7'b0100011 : begin // S-type sw, sb
                // rs1 = register containing base address
                // rs2 = register containing data that needs to be stored
                // imm = offset to base address that gives the target address

                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

                op = ADD;
    
                case (funct3)
                    3'b000 : sz = BYTE;
                    3'b001 : sz = H_WORD;
                    3'b010 : sz = WORD;
                endcase
                
                store_enable = 1'b1;
                ALUSrc = 1'b1;
                rs1_num = rs1;
                rs2_num = rs2;

            end
            7'b0000011 : begin // L-type lw, lb
                imm = {{20{instr[31]}}, instr[31:20]};

                op = ADD;
    
                case (funct3)
                    3'b000 : sz = BYTE;
                    3'b001 : sz = H_WORD;
                    3'b010 : sz = WORD;
                    3'b100 : sz = BYTE_U;
                    3'b101 : sz = H_WORD_U;
                endcase

                load_enable = 1'b1;
                rd_enable = 1'b1;
                ALUSrc = 1'b1;
                rs1_num = rs1;
                rd_num = rd;
                
            end
            7'b1100011 : begin // B-type beq, bne
                imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8] , 1'b0};

                case (funct3)
                    3'b000 : op = XOR; // check if the xor result is perfectly 0, then is equal, beq
                    3'b001 : op = XOR; // if xor is not 0, then not perfectly equal, bne
                    3'b100 : op = SLT; // if get 1, then is less than, blt
                    3'b101 : op = SLT; // if get 0, then is greater or equal, bge
                    3'b110 : op = SLTU; // bltu
                    3'b111 : op = SLTU; // bgeu
                endcase

                rs1_num = rs1;
                rs2_num = rs2;
                branch_enable = 1'b1;
                branch_type = funct3;
            end
            7'b0110111 : begin // U-type lui
                imm = {instr[31:12], {12{1'b0}}}; 
                op = PASS;
                ALUSrc = 1'b1;
                rd_num = rd;
                rd_enable = 1'b1;

            end
            7'b0010111 : begin // U-type auipc, add upper immediate to pc
                imm = {instr[31:12], {12{1'b0}}}; 

                op = PASS;

                use_pc = 1'b1;
                ALUSrc = 1'b1;
                rd_num = rd;
                rd_enable = 1'b1;
            end
            // Difference: JALR compute absolute address from register whereas JAL compute PC-relative address
            7'b1101111 : begin // J-type jal
                imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
                
                // this lets it know that this is a jump instruction, and so rd contains PC+4 not ALU output
                jump_enable = 1'b1;
                use_pc = 1'b1;
                ALUSrc = 1'b1;
                rd_enable = 1'b1;
                rd_num = rd;
            end
            7'b1100111 : begin // I-type jalr
                imm = {{20{instr[31]}}, instr[31:20]};
                
                jump_enable = 1'b1;
                ALUSrc = 1'b1;
                rd_enable = 1'b1;
                rs1_num = rs1;
                rd_num = rd;
            end
            
        endcase

    end 

    assign immediate = imm;
    assign ALU_ctrl = op;
    assign size = sz;

endmodule
