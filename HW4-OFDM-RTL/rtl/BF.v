module BF
#(
    parameter  TOTAL_BITS = 20,
    parameter  FRACTION_BITS = 8
)
(

input select,      
input signed[TOTAL_BITS-1:0] twiddle_factors1,
input signed[TOTAL_BITS-1:0] twiddle_factors0,
input signed [TOTAL_BITS-1:0] in_low0,	// 0
input signed [TOTAL_BITS-1:0] in_low1,	// 0
input signed [TOTAL_BITS-1:0] in_high0,	// 20
input signed [TOTAL_BITS-1:0] in_high1,	// 20
output reg signed [2*TOTAL_BITS-1:0] code_high,
output reg signed [2*TOTAL_BITS-1:0] code_low    
);

reg signed [TOTAL_BITS-1:0] T2 [1:0];
reg signed [25:0] x2 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] q_x2 [1:0][1:0];
reg signed [2*TOTAL_BITS-1:0] final_high;
reg signed [2*TOTAL_BITS-1:0] final_low;
reg signed [TOTAL_BITS-1:0] T2_tmp0 [1:0];
reg signed [TOTAL_BITS-1:0] T2_tmp1 [1:0];
reg signed [2*TOTAL_BITS-1:0] tmp0 [1:0];
reg signed [2*TOTAL_BITS-1:0] tmp1 [1:0];
always @(*) begin
    tmp0[1] = twiddle_factors1 * in_high0 + (1 << (FRACTION_BITS - 1));
    tmp0[0] = twiddle_factors0 * in_high1 + (1 << (FRACTION_BITS - 1));
    tmp1[1] = twiddle_factors1 * in_high1 + (1 << (FRACTION_BITS - 1));
    tmp1[0] = twiddle_factors0 * in_high0 + (1 << (FRACTION_BITS - 1));

    T2_tmp0[1] = tmp0[1] >>> FRACTION_BITS;
    T2_tmp0[0] = tmp0[0] >>> FRACTION_BITS;
    T2_tmp1[1] = tmp1[1] >>> FRACTION_BITS;
    T2_tmp1[0] = tmp1[0] >>> FRACTION_BITS;
    T2[0] = T2_tmp0[1] + T2_tmp0[0];
    T2[1] = T2_tmp1[1] - T2_tmp1[0];

    x2[0][1] =  in_low1 + T2[1];
    x2[0][0] =  in_low0 + T2[0];
    x2[1][1] =  in_low1 - T2[1];
    x2[1][0] =  in_low0 - T2[0];

    if(x2[0][1] > 2047)
        q_x2[0][1] = 2047;
    else if(x2[0][1] < -2048)
        q_x2[0][1] = -2048;
    else
        q_x2[0][1] = x2[0][1];
    
    if(x2[0][0] > 2047)
        q_x2[0][0] = 2047;
    else if(x2[0][0] < -2048)
        q_x2[0][0] = -2048;
    else
        q_x2[0][0] = x2[0][0];
    
    if(x2[1][1] > 2047)
        q_x2[1][1] = 2047;
    else if(x2[1][1] < -2048)
        q_x2[1][1] = -2048;
    else
        q_x2[1][1] = x2[1][1];
    
    if(x2[1][0] > 2047)
        q_x2[1][0] = 2047;
    else if(x2[1][0] < -2048)
        q_x2[1][0] = -2048;
    else
        q_x2[1][0] = x2[1][0];   

    final_high = {q_x2[1][1], q_x2[1][0]};
    final_low = {q_x2[0][1], q_x2[0][0]};
     code_high = select ? {in_low1, in_low0}: final_low;
     code_low = select ? {in_high1, in_high0}: final_high;
end


endmodule