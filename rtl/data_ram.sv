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
    logic [31:0] memory [0:959]; // 960 memory blocks each 32 bits

    logic [31:0] word_addr;
    logic [1:0] byte_index;
    logic [4:0] bit_index_ms;

    assign word_addr = mem_addr >> 2;
    assign byte_index = mem_addr[1:0];

    always_comb begin
        bit_index_ms = 5'd7;
        if (data_size == H_WORD || data_size == H_WORD_U)
            bit_index_ms = byte_index * 8 + 15;
        else
            bit_index_ms = byte_index * 8 + 7;
    end

    // block RAM physically requries loads to be done sequentially, not combinationally,
    // need clk edge between giving address and getting data stored there back
    // cannot do the instant read/combinational of block RAM, that's why "get/freeze" the data
    // for this clk cycle and can always_comb and slice this data however
    logic [31:0] mem_word_reg;
    logic ld_valid_reg;
    logic [4:0] bit_index_ms_reg;
    st_ld_size data_size_reg;

    always_ff @(posedge clk) begin
        bit_index_ms_reg <= bit_index_ms;
        ld_valid_reg <= ld_enable && dataram_sel;
        data_size_reg <= data_size;
        mem_word_reg <= memory[word_addr]; // this is so that you can read from it combinationally afterwards, as it is updated sequentially

        // Byte/halfword writes now use STATIC bit ranges, selected via a case
        // on byte_index, instead of a dynamically-shifted part-select
        // (memory[word_addr][bit_index_ms -: 8] <= ...). Real block RAM can
        // only do byte-enable writes at fixed, compile-time-known lane
        // boundaries - a write whose bit position is computed from a runtime
        // signal isn't something the hardware can do at all
        if (st_enable && dataram_sel) begin
            case (data_size)
                WORD : memory[word_addr] <= st_data;
                BYTE, BYTE_U : begin
                    case (byte_index)
                        2'b0 : memory[word_addr][7:0] <= st_data[7:0];
                        2'b1 : memory[word_addr][15:8] <= st_data[7:0];
                        2'b10 : memory[word_addr][23:16] <= st_data[7:0];
                        2'b11 : memory[word_addr][31:24] <= st_data[7:0];
                        default : ;
                    endcase
                    memory[word_addr][bit_index_ms -: 8] <= st_data[7:0];
                end
                H_WORD, H_WORD_U : begin
                    case (byte_index)
                        1'b0 : memory[word_addr][15:0] <= st_data[15:0];
                        1'b1 : memory[word_addr][31:16] <= st_data[15:0];
                        default : ;
                    endcase
                end
                default : ;
            endcase
        end
    end

    // can still read with dynamic bit position, just not write
    always_comb begin
        dataram_read_data = 32'b0;
        if (ld_valid_reg) begin // condition upon ld_valid_reg, data_size_reg, bit_index_ms_reg because want conditons
                                // to be the same as when copied value of memory at that word address in always_ff
            case (data_size_reg)
                // -: is WIDTH, must be constant, # of bits inclusive
                BYTE : dataram_read_data = {{24{mem_word_reg[bit_index_ms_reg]}}, {mem_word_reg[bit_index_ms_reg -: 8]}};
                H_WORD : dataram_read_data = {{16{mem_word_reg[bit_index_ms_reg]}}, {mem_word_reg[bit_index_ms_reg -: 16]}};
                WORD : dataram_read_data = mem_word_reg;
                BYTE_U : dataram_read_data = {{24'b0}, {mem_word_reg[bit_index_ms_reg -: 8]}};
                H_WORD_U : dataram_read_data = {{16'b0}, {mem_word_reg[bit_index_ms_reg -: 16]}};
                default: ;
            endcase
        end
    end

endmodule
