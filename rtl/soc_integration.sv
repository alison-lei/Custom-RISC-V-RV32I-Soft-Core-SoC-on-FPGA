// move this to a higher level
// register_file .u0 (.clk(clk), .reset(reset), .rd_enable(0), .rs1_num(rs1), .rs2_num(rs2), .rs1_data(rs1_data), .rs2_data(rs2_data));

register_file u0 (.clk(clk), .reset(reset), rd_enable(1'b0), .rs1_num(rs1_num), .rs2_num(rs2_num),
                    .rd_num(), .rd_data(), .rs1_data(rs1_data), .rs2_data(rs2_data));
