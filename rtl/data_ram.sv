`timescale 1ns / 1ns

module data_ram (
    input logic clk,
    input logic dataram_sel,
    input logic ld_enable, st_enable,
    input logic [2:0] size,
    input logic [31:0] st_data, mem_addr,
    output logic [31:0] dataram_read_data
);
    typedef enum logic [2:0] {
                            BYTE = 3'b000,
                            H_WORD = 3'b001,
                            WORD = 3'b010,
                            BYTE_U = 3'b011,
                            H_WORD_U = 3'b100
    } st_ld_size;

    st_ld_size data_size;
    assign data_size = st_ld_size'(size);

    // this memory is word granularity
    logic [31:0] memory [0:255]; // 256 memory blocks each 32 bits, 1KB

    logic [31:0] ld_data_temp;
    logic [29:0] word_addr;
    logic [1:0] byte_index;
    logic [4:0] bit_index_ms;

    assign word_addr = mem_addr >> 2;
    assign byte_index = mem_addr[1:0];

    always_comb begin
        ld_data_temp = 32'b0;
        bit_index_ms = 5'd7;

        if (data_size == H_WORD || data_size == H_WORD_U)
            bit_index_ms = byte_index * 8 + 15;
        else
            bit_index_ms = byte_index * 8 + 7;

        if (ld_enable && dataram_sel) begin // can do reading in combination block
            case (data_size)
                // -: is WIDTH, must be constant, # of bits inclusive
                BYTE : ld_data_temp = {{24{memory[word_addr][bit_index_ms]}}, {memory[word_addr][bit_index_ms -: 8]}};
                H_WORD : ld_data_temp = {{16{memory[word_addr][bit_index_ms]}}, {memory[word_addr][bit_index_ms -: 16]}};
                WORD : ld_data_temp = memory[word_addr];
                BYTE_U : ld_data_temp = {{24'b0}, {memory[word_addr][bit_index_ms -: 8]}};
                H_WORD_U : ld_data_temp = {{16'b0}, {memory[word_addr][bit_index_ms -: 16]}};
                default: ld_data_temp = 32'b0;
            endcase
        end
    end

    // can only write once in one cycle, is state change that needs to be clocked
    always_ff @(posedge clk) begin
        if (st_enable && dataram_sel) begin
            case (data_size)
                BYTE : memory[word_addr][bit_index_ms -: 8] = st_data[7:0];
                H_WORD : memory[word_addr][bit_index_ms -: 16] = st_data[15:0];
                WORD : memory[word_addr] = st_data;
                BYTE_U : memory[word_addr][bit_index_ms -: 8] = st_data[7:0];
                H_WORD_U : memory[word_addr][bit_index_ms -: 16] = st_data[15:0];
                default : ;
            endcase
        end
    end

    assign dataram_read_data = load_data_temp;

endmodule
