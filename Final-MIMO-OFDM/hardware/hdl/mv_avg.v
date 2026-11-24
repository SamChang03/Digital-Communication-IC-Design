module mv_avg
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

    input signed [TOTAL_BIT-1:0] data_in,

    output wire signed [TOTAL_BIT-1:0] data_out,
    output wire data_out_valid
);

localparam ACC_WIDTH = TOTAL_BIT + FIFO_WIDTH_LOG;

reg [ACC_WIDTH-1:0] accu_value;
wire [ACC_WIDTH-1:0] accu_value_n;
wire FIFO_full;

wire [TOTAL_BIT-1:0] data_delay;
reg [FIFO_WIDTH_LOG:0] output_valid_cnt;

wire signed [ACC_WIDTH-1:0] data_in_ext;
wire signed [ACC_WIDTH-1:0] data_delay_ext;

//----------------- Data Extension -----------------//
wire sign_data_in = data_in[TOTAL_BIT-1];
wire sign_data_delay = data_delay[TOTAL_BIT-1];

assign data_in_ext    = { {FIFO_WIDTH_LOG{sign_data_in}}, data_in };
assign data_delay_ext = { {FIFO_WIDTH_LOG{sign_data_delay}}, data_delay };

//----------------- Delay FIFO --------------------//
FIFO_delay #(
    .FIFO_LENGTH(FIFO_LENGTH),.FIFO_WIDTH_LOG(FIFO_WIDTH_LOG),
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
) u_dut (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),

    .data_in(data_in),

    .data_out(data_delay)
);


//----------------- Accumulation --------------------//

assign accu_value_n = (enable) ? data_in_ext + accu_value - data_delay_ext : accu_value;

always @(posedge clk) begin
    if (~rst_n) begin
        accu_value <= 0;
    end
    else begin
        accu_value <= accu_value_n;
    end
end

//----------------- Output Stage --------------------//
assign data_out = accu_value[ACC_WIDTH-1 : FIFO_WIDTH_LOG];
assign FIFO_full = (output_valid_cnt == FIFO_LENGTH);
assign data_out_valid = FIFO_full;

always @(posedge clk) begin
    if (~rst_n) begin
        output_valid_cnt <= 0;
    end
    else begin
        output_valid_cnt <= (enable) 
                            ? (FIFO_full) ? output_valid_cnt : output_valid_cnt+1 
                            : output_valid_cnt;
    end
end

endmodule