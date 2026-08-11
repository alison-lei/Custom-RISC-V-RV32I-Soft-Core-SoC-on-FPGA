`timescale 1ns / 1ns

module spi_controller (
    input logic clk, reset, start,
    input logic [7:0] pixel_data,
    output sclk, cs, mosi,
    output logic done
);
    // the input clk is the FPGA, around 50MHz
    // need to be slower, 5MHz, so need clock divider

    typedef enum logic [1:0] {
                            IDLE = 2'b0,
                            DATA = 2'b1,
                            STOP = 2'b10
    } state;

    localparam int CLK_FREQ = 50_000_000; // 50 MHz
    localparam int SCLK = 5_000_000; // 5MHz
    localparam int CLK_DIV = CLK_FREQ / SCLK; // 10
    localparam int CLK_DIV_HALF = CLK_DIV / 2; // 5, so have half of the period

    // in ports have sclk which is the slower clock
    int cyc_count = 0;
    state statetype = IDLE;
    logic signed [3:0] bit_index = 7; // because need to check at -1
    logic mosi_data_bit = 1'b0;

    // clk divider in this always_ff block
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sclk <= 1'b0;
            cyc_count <= 0;
        end
        else begin
            if (cyc_count == CLK_DIV_HALF - 1) begin
                sclk <= !sclk;
                cyc_count <= 0;
            end
            else
                cyc_count <= cyc_count + 1;
        end
    end

    // master load in pixel data
    // does it need to be negedge, or can it be posedge
    always_ff @(negedge sclk or posedge reset) begin
        done <= 1'b0;
        if (reset)
            statetype <= IDLE; // idles high
        else begin
            case (statetype)
                IDLE : begin
                    if (start)
                        statetype <= DATA;
                end
                DATA : begin
                    if (bit_index != -1) begin
                        mosi_data_bit <= pixel_data[bit_index];
                        bit_index <= bit_index - 1;
                    end
                    else begin
                        statetype <= STOP;
                        bit_index <= 7;
                    end
                end
                STOP : begin
                    done <= 1'b1;
                    statetype <= IDLE;
                end
                default : ;
            endcase
        end
    end

    assign cs = (statetype == DATA) ? 1'b0 : 1'b1;
    assign mosi = (cs == 1'b0) ? mosi_data_bit : 1'b0;

endmodule
