module mv_avg_dual_ch
#(
    parameter FIFO_LENGTH = 16,
    parameter FIFO_WIDTH_LOG  = 4,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
)
(
    input clk,
    input rst_n,
    input enable,

    input signed [FIFO_LENGTH-1:0] data_in0,
    input signed [FIFO_LENGTH-1:0] data_in1,

    output signed [FIFO_LENGTH-1:0] data_out0,
    output signed [FIFO_LENGTH-1:0] data_out1,
    output data_out_valid
);

mv_avg #(
    .FIFO_LENGTH(FIFO_LENGTH), .FIFO_WIDTH_LOG(FIFO_WIDTH_LOG),
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
) 
channel_1 (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),

    .data_in(data_in0),
    
    .data_out(data_out0),
    .data_out_valid()
);

mv_avg #(
    .FIFO_LENGTH(FIFO_LENGTH), .FIFO_WIDTH_LOG(FIFO_WIDTH_LOG),
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
) channel_2 (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),

    .data_in(data_in1),
    
    .data_out(data_out1),
    .data_out_valid(data_out_valid)
);

endmodule