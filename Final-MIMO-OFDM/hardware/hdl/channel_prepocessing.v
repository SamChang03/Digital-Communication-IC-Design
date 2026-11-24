// =================================================//
//                   Zero-Forcing                   //
// =================================================//

module channel_prepocessing #
(
    parameter FIFO_LENGTH = 32,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
)
(
    input clk,
    input rst_n,
    input enable,
    // Channel Coefficients (H Matrix)
    input signed [TOTAL_BIT-1:0] channel_AA_re, // h_11
    input signed [TOTAL_BIT-1:0] channel_AA_im,
    input signed [TOTAL_BIT-1:0] channel_AB_re, // h_21 (TX A -> RX B)
    input signed [TOTAL_BIT-1:0] channel_AB_im,
    input signed [TOTAL_BIT-1:0] channel_BA_re, // h_12 (TX B -> RX A)
    input signed [TOTAL_BIT-1:0] channel_BA_im,
    input signed [TOTAL_BIT-1:0] channel_BB_re, // h_22
    input signed [TOTAL_BIT-1:0] channel_BB_im,

    output reg signed [TOTAL_BIT-1:0] inv_channel_AA_re, // h_11
    output reg signed [TOTAL_BIT-1:0] inv_channel_AA_im,
    output reg signed [TOTAL_BIT-1:0] inv_channel_AB_re, // h_21 (TX A -> RX B)
    output reg signed [TOTAL_BIT-1:0] inv_channel_AB_im,
    output reg signed [TOTAL_BIT-1:0] inv_channel_BA_re, // h_12 (TX B -> RX A)
    output reg signed [TOTAL_BIT-1:0] inv_channel_BA_im,
    output reg signed [TOTAL_BIT-1:0] inv_channel_BB_re, // h_22
    output reg signed [TOTAL_BIT-1:0] inv_channel_BB_im,

    output reg channel_prepocessing_valid
);

reg channel_prepocessing_valid_FF;

// -------------------------------------------------//
//              Step 1 Calculate det(H)             //
// -------------------------------------------------//

wire signed [TOTAL_BIT-1:0] determinant_re, determinant_im;
wire signed [TOTAL_BIT-1:0] mul_1_re, mul_1_im, 
                            mul_2_re, mul_2_im;

// h11*h22
complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
complex_mult_1 
(
    .din_re(channel_AA_re),
    .din_im(channel_AA_im),
    .din_2_re(channel_BB_re),
    .din_2_im(channel_BB_im),

    .dout_re(mul_1_re),
    .dout_im(mul_1_im)
);

// h12*h21
complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
complex_mult_2 
(
    .din_re(channel_AB_re),
    .din_im(channel_AB_im),
    .din_2_re(channel_BA_re),
    .din_2_im(channel_BA_im),

    .dout_re(mul_2_re),
    .dout_im(mul_2_im)
);

// det(H) = h11*h22- h12*h21
complex_sub #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) BF_sub (
    .a_re(mul_1_re), .a_im(mul_1_im),
    .b_re(mul_2_re), .b_im(mul_2_im),

    .y_re(determinant_re), .y_im(determinant_im)
);

// -------------------------------------------------//
//            Step 1.5 Insert Flip-flop             //
// -------------------------------------------------//
reg signed [TOTAL_BIT-1:0] determinant_re_FF, determinant_im_FF;

reg signed [TOTAL_BIT-1:0] channel_AA_re_FF, channel_AA_im_FF;
reg signed [TOTAL_BIT-1:0] channel_AB_re_FF, channel_AB_im_FF;
reg signed [TOTAL_BIT-1:0] channel_BA_re_FF, channel_BA_im_FF;
reg signed [TOTAL_BIT-1:0] channel_BB_re_FF, channel_BB_im_FF;

always @(posedge clk) begin
    // countrol valid
    if (~rst_n) begin
        channel_prepocessing_valid_FF <= 0;
    end
    else begin
        channel_prepocessing_valid_FF <= enable;
    end
    // determinant
    determinant_re_FF<= determinant_re;
    determinant_im_FF <= determinant_im;

    // Channel dalay
    channel_AA_re_FF <= channel_AA_re;
    channel_AA_im_FF <= channel_AA_im;

    channel_AB_re_FF <= channel_AB_re;
    channel_AB_im_FF <= channel_AB_im;

    channel_BA_re_FF <= channel_BA_re;
    channel_BA_im_FF <= channel_BA_im;

    channel_BB_re_FF <= channel_BB_re;
    channel_BB_im_FF <= channel_BB_im;
end

// -------------------------------------------------//
//             Step 2 Calculate det(H)*             //
// -------------------------------------------------//

wire signed [TOTAL_BIT-1:0] deter_conj_re, deter_conj_im;
assign deter_conj_re = (determinant_re_FF) >>6;
assign deter_conj_im = (~determinant_im_FF + 1) >>6;

// -------------------------------------------------//
//             Step 3 Inverse Operation             //
// -------------------------------------------------//

wire signed [TOTAL_BIT-1:0] inv_channel_AA_re_adjugate, inv_channel_AA_im_adjugate;
wire signed [TOTAL_BIT-1:0] inv_channel_AB_re_adjugate, inv_channel_AB_im_adjugate;
wire signed [TOTAL_BIT-1:0] inv_channel_BA_re_adjugate, inv_channel_BA_im_adjugate;
wire signed [TOTAL_BIT-1:0] inv_channel_BB_re_adjugate, inv_channel_BB_im_adjugate;

assign inv_channel_AA_re_adjugate = channel_BB_re_FF;
assign inv_channel_AA_im_adjugate = channel_BB_im_FF;

assign inv_channel_BB_re_adjugate = channel_AA_re_FF;
assign inv_channel_BB_im_adjugate = channel_AA_im_FF;

assign inv_channel_AB_re_adjugate = ~channel_BA_re_FF+1;
assign inv_channel_AB_im_adjugate = ~channel_BA_im_FF+1;

assign inv_channel_BA_re_adjugate = ~channel_AB_re_FF+1;
assign inv_channel_BA_im_adjugate = ~channel_AB_im_FF+1;

// -------------------------------------------------//
//               Step 4 Multiply det(H)*            //
// -------------------------------------------------//

wire signed [TOTAL_BIT-1:0] inv_channel_AA_re_FF, inv_channel_AA_im_FF;
wire signed [TOTAL_BIT-1:0] inv_channel_AB_re_FF, inv_channel_AB_im_FF;
wire signed [TOTAL_BIT-1:0] inv_channel_BA_re_FF, inv_channel_BA_im_FF;
wire signed [TOTAL_BIT-1:0] inv_channel_BB_re_FF, inv_channel_BB_im_FF;

// inverse h11
complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
inverse_11 
(
    .din_re(inv_channel_AA_re_adjugate),
    .din_im(inv_channel_AA_im_adjugate),
    .din_2_re(deter_conj_re),
    .din_2_im(deter_conj_im),

    .dout_re(inv_channel_AA_re_FF),
    .dout_im(inv_channel_AA_im_FF)
);

// inverse h12
complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
inverse_12 
(
    .din_re(inv_channel_AB_re_adjugate),
    .din_im(inv_channel_AB_im_adjugate),
    .din_2_re(deter_conj_re),
    .din_2_im(deter_conj_im),

    .dout_re(inv_channel_AB_re_FF),
    .dout_im(inv_channel_AB_im_FF)
);

// inverse h21
complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
inverse_21 
(
    .din_re(inv_channel_BA_re_adjugate),
    .din_im(inv_channel_BA_im_adjugate),
    .din_2_re(deter_conj_re),
    .din_2_im(deter_conj_im),

    .dout_re(inv_channel_BA_re_FF),
    .dout_im(inv_channel_BA_im_FF)
);

// inverse h22
complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
inverse_22 
(
    .din_re(inv_channel_BB_re_adjugate),
    .din_im(inv_channel_BB_im_adjugate),
    .din_2_re(deter_conj_re),
    .din_2_im(deter_conj_im),

    .dout_re(inv_channel_BB_re_FF),
    .dout_im(inv_channel_BB_im_FF)
);

// -------------------------------------------------//
//              Step 5 Insert Flip-flop             //
// -------------------------------------------------//

always @(posedge clk) begin
    // countrol valid
    if (~rst_n) begin
        channel_prepocessing_valid <= 0;
    end
    else begin
        channel_prepocessing_valid <= channel_prepocessing_valid_FF;
    end
    // inverse channel
    inv_channel_AA_re <= inv_channel_AA_re_FF;
    inv_channel_AA_im <= inv_channel_AA_im_FF;

    inv_channel_AB_re <= inv_channel_AB_re_FF;
    inv_channel_AB_im <= inv_channel_AB_im_FF;

    inv_channel_BA_re <= inv_channel_BA_re_FF;
    inv_channel_BA_im <= inv_channel_BA_im_FF;

    inv_channel_BB_re <= inv_channel_BB_re_FF;
    inv_channel_BB_im <= inv_channel_BB_im_FF;
end

endmodule