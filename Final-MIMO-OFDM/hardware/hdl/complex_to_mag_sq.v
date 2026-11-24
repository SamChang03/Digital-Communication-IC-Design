module complex_to_mag_sq
#(
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
)
(
    input signed [TOTAL_BIT-1:0] i,
    input signed [TOTAL_BIT-1:0] q,

    output [TOTAL_BIT-1:0] mag_sq
);

wire [TOTAL_BIT-1:0] q_neg;
assign q_neg = (~q)+1;

//------------ |Z|^2 = Z x Z* ----------//
complex_mult  #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) 
mult_inst
(
    .din_re(i), // a
    .din_im(q), // b
    .din_2_re(i),  // c (Twiddle Real)
    .din_2_im(q_neg),  // d (Twiddle Imag)
    
    .dout_re(mag_sq),
    .dout_im()
);


endmodule