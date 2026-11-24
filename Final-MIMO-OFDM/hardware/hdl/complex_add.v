module complex_add #(
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
) (
    input signed [TOTAL_BIT-1:0] a_re,
    input signed [TOTAL_BIT-1:0] a_im,
    input signed [TOTAL_BIT-1:0] b_re,
    input signed [TOTAL_BIT-1:0] b_im,

    output signed [TOTAL_BIT-1:0] y_re,
    output signed [TOTAL_BIT-1:0] y_im
);
// Max Positive: 0111...1
localparam signed [TOTAL_BIT-1:0] MAX_POS = {1'b0, {(TOTAL_BIT-1){1'b1}}};

// Min Negative: 1000...0
localparam signed [TOTAL_BIT-1:0] MIN_NEG = {1'b1, {(TOTAL_BIT-1){1'b0}}};

///////********** ADD *************///////
wire signed [TOTAL_BIT:0] sum_re, sum_im;

// sum (add one more bit)
assign sum_re = a_re + b_re;
assign sum_im = a_im + b_im;

// ---------------------------------------------------------------------
//                              Truncation
// ---------------------------------------------------------------------
wire signed [TOTAL_BIT-1:0] boundary_re, boundary_im;
wire overflow_re, overflow_im;

// check overflow
assign overflow_re = sum_re[TOTAL_BIT] ^ sum_re[TOTAL_BIT-1];
assign overflow_im = sum_im[TOTAL_BIT] ^ sum_im[TOTAL_BIT-1];

// check sign of sum
assign boundary_re = (sum_re[TOTAL_BIT]) ? MIN_NEG : MAX_POS ;
assign boundary_im = (sum_im[TOTAL_BIT]) ? MIN_NEG : MAX_POS ;

// truncation main
assign y_re = (overflow_re) ? boundary_re: sum_re[TOTAL_BIT-1:0];
assign y_im = (overflow_im) ? boundary_im: sum_im[TOTAL_BIT-1:0];
    
endmodule