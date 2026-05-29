`timescale 1ns / 1ns

module decode (
    input logic clk, input logic [31:0] instr,
    output logic [3:0] ALU_ctrl, output logic [31:0] rs1, rs2, immediate, output logic jump_b, branch_b, rd_enable
);
    logic [31:0] imm;

    logic [6:0]  funct7;
    logic [4:0]  rs2;
    logic [4:0]  rs1;
    logic [2:0]  funct3;
    logic [4:0]  rd;
    logic [6:0] opcode;

    assign opcode = instr[6:0];
    assign funct7 = instr[31:25];
    assign rs2 = instr[24:20];
    assign rs1 = instr[19:15];
    assign funct3 = instr[14:12];
    assign rd = instr[11:7];

    always_comb begin
        case (opcode)
            default : begin
                imm = 32'b0;
                mem_r = 0;
                mem_w = 0;

            end
            7'b0110011 : begin // R-type
                mem_r = 1;
                case (funct7)

                endcase
            end
            7'b0010011 : begin // I-type addi, slli, lw
                imm = {{20{instr[31]}}, instr[31:20]};
            end
            7'b0100011 : begin // S-type sw, sb
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end
            7'b1100011 : begin // B-type beq, bne
                imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8] , 1'b0};
            end
            7'b0110111 : begin // U-type lui
                imm = {instr[31:12], {12{1'b0}}};
            end
            7'b0010111 : begin // U-type auipc
                imm = {instr[31:12], {12{1'b0}}};
            end
            7'b1101111 : begin // J-type jal
                imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            end
            
            
            
        // next steps is create register_file that reads values in registers given their addresses
        // call register_file at end when assign all the enables and everything
        endcase

    end    

endmodule


module register_file (
    input logic clk, reset,
    output logic [31:0] rs1_data, rs2_data
);

endmodule