module complex_to_mag
#(
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
)
(
    input signed [TOTAL_BIT-1:0] i,
    input signed [TOTAL_BIT-1:0] q,

    output [TOTAL_BIT-1:0] mag
);

wire [TOTAL_BIT-1:0] abs_i;
wire [TOTAL_BIT-1:0] abs_q;

wire [TOTAL_BIT-1:0] max;
wire [ TOTAL_BIT-1:0] min;

reg input_valid_reg0;
reg input_valid_reg1;

//---------------- ABS (2's complement) ---------------------//
assign abs_q = q[TOTAL_BIT-1]? (~q+1): q;
assign abs_i = i[TOTAL_BIT-1]? (~i+1): i;

//--------- Find max(|I|, |Q|), min(|I|, |Q|) -----------//
assign max = (abs_i > abs_q) ? abs_i: abs_q;
assign min = (abs_i > abs_q) ? abs_q: abs_i;

//--------- Mag = max(|I|, |Q|)+ 1/4*min(|I|, |Q|) -----------//
assign mag = max + (min>>2);

endmodule