module BF2 #(
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
) (
    input BF_mode, // BF_mode: 0 --> Bypass ; BF_mode:1 --> BF
    input signed [TOTAL_BIT-1:0] data_in_u_re,
    input signed [TOTAL_BIT-1:0] data_in_u_im,
    input signed [TOTAL_BIT-1:0] data_in_t_re,
    input signed [TOTAL_BIT-1:0] data_in_t_im,

    output signed [TOTAL_BIT-1:0] data_out_u_re,
    output signed [TOTAL_BIT-1:0] data_out_u_im,
    output signed [TOTAL_BIT-1:0] data_out_t_re,
    output signed [TOTAL_BIT-1:0] data_out_t_im
);

// Select by BF_mode
wire signed [TOTAL_BIT-1:0] sum_re, sum_im, sub_re, sub_im;

// upper
assign data_out_u_re = (~BF_mode) ? data_in_t_re : sub_re;
assign data_out_u_im = (~BF_mode) ? data_in_t_im : sub_im;

// lower
assign data_out_t_re = (~BF_mode) ? data_in_u_re : sum_re;
assign data_out_t_im = (~BF_mode) ? data_in_u_im : sum_im;

// Complex Adder
complex_add #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) BF_add (
    .a_re(data_in_u_re), .a_im(data_in_u_im),
    .b_re(data_in_t_re), .b_im(data_in_t_im),

    .y_re(sum_re), .y_im(sum_im)
);

// Complex Subtractor
complex_sub #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) BF_sub (
    .a_re(data_in_u_re), .a_im(data_in_u_im),
    .b_re(data_in_t_re), .b_im(data_in_t_im),

    .y_re(sub_re), .y_im(sub_im)
);

endmodule