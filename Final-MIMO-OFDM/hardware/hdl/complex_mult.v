module complex_mult  #(
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT  = 8
) (
    input  wire signed [TOTAL_BIT-1:0] din_re, // a
    input  wire signed [TOTAL_BIT-1:0] din_im, // b
    input  wire signed [TOTAL_BIT-1:0] din_2_re,  // c (Twiddle Real)
    input  wire signed [TOTAL_BIT-1:0] din_2_im,  // d (Twiddle Imag)
    
    output wire signed [TOTAL_BIT-1:0] dout_re,
    output wire signed [TOTAL_BIT-1:0] dout_im
);

    // Double Width
    wire signed [2*TOTAL_BIT-1:0] k_re, k_im;
    wire signed [2*TOTAL_BIT-1:0] mult_ac, mult_bd, mult_ad, mult_bc;

    //------------------ Multiplication ----------------------//
    assign mult_ac = din_re * din_2_re;
    assign mult_bd = din_im * din_2_im;
    assign mult_ad = din_re * din_2_im;
    assign mult_bc = din_im * din_2_re;

    //------------------ Addition ----------------------//
    assign k_re = mult_ac - mult_bd;
    assign k_im = mult_ad + mult_bc;

    // ---------------------------------------------------------------------
    //                              Truncation
    // ---------------------------------------------------------------------
    assign dout_re = k_re[TOTAL_BIT + FRAC_BIT - 1 : FRAC_BIT];
    assign dout_im = k_im[TOTAL_BIT + FRAC_BIT - 1 : FRAC_BIT];

endmodule