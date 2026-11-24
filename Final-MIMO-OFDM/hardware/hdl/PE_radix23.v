module PE_radix23 #(
    parameter FIFO_LENGTH = 32,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
) (
    input clk,
    input rst_n,
    input in_valid,
    input FIFO_enable,
    input BF_mode, // Mode: 0 --> Bypass ; Mode:1 --> BF
    input signed [TOTAL_BIT-1:0] din_re,
    input signed [TOTAL_BIT-1:0] din_im,

    output dout_valid,
    output signed [TOTAL_BIT-1:0] dout_re,
    output signed [TOTAL_BIT-1:0] dout_im
);

wire signed [TOTAL_BIT-1:0] FIFO_in_re, FIFO_in_im;
wire signed [TOTAL_BIT-1:0] FIFO_out_re, FIFO_out_im;

// --------------------------------------------------------------------- //
//                      Butterfly Processor                              //
// --------------------------------------------------------------------- //
BF2 #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
) 
BF2_stage1
(
    .BF_mode(BF_mode), // Mode: 0 --> Bypass ; Mode:1 --> BF
    .data_in_u_re(FIFO_out_re), .data_in_u_im(FIFO_out_im),
    .data_in_t_re(din_re), .data_in_t_im(din_im),

    .data_out_u_re(FIFO_in_re), .data_out_u_im(FIFO_in_im),
    .data_out_t_re(dout_re), .data_out_t_im(dout_im)
);

// --------------------------------------------------------------------- //
//                             Delay FIFO                                //
// --------------------------------------------------------------------- //

//----------------- Delay FIFO --------------------//
FIFO_delay_complex #(
    .FIFO_LENGTH(FIFO_LENGTH),.FIFO_WIDTH_LOG(FIFO_WIDTH_LOG),
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)  FIFO_stage1 (
    .clk(clk),
    .rst_n(rst_n),
    .enable(FIFO_enable),

    .data_in_re(FIFO_in_re),
    .data_in_im(FIFO_in_im),

    .data_out_re(FIFO_out_re),
    .data_out_im(FIFO_out_im)
);

//--------------- Simple FSM -----------------//
reg [FIFO_LENGTH-1:0] valid_sr;
always @(posedge clk) begin
    if (~rst_n) valid_sr <= 0;
    else valid_sr <= {valid_sr[FIFO_LENGTH-1:0], in_valid};
end

assign dout_valid = valid_sr[FIFO_LENGTH-1];

endmodule