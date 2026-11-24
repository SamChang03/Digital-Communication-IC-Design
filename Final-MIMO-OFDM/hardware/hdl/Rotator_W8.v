module Rotator_W8 #(
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT  = 8  // Used for fixed-point shifting (e.g., 0.707 = 181 / 2^8)
)(
    input in_valid,
    
    // Control signal: Determines the power of W8 (W8^0, W8^1, W8^2, W8^3, etc.)
    // Typically derived from counter bits (e.g., cnt[5:3] or cnt[2:0])
    input [2:0] cnt_region, 
    
    input signed [TOTAL_BIT-1:0] din_re,
    input signed [TOTAL_BIT-1:0] din_im,

    output reg dout_valid,
    output reg signed [TOTAL_BIT-1:0] dout_re,
    output reg signed [TOTAL_BIT-1:0] dout_im
);

    // ============================================================
    // 1. Constant Definition (0.7071 in Q8.8 fixed-point format)
    // ============================================================
    // 0.707106 * 2^8 = 181.019 (Fixed-point constant for 1/sqrt(2))
    localparam signed [TOTAL_BIT-1:0] COEFF_0_707 = 181;

    // ============================================================
    // 2. Pre-calculation (I+Q) and (I-Q) terms
    // ============================================================
    // Intermediate width expanded by 1 bit for addition/subtraction safety
    wire signed [TOTAL_BIT:0] sum_IQ, diff_IQ; 
    
    assign sum_IQ  = din_re + din_im;      // (I + Q)
    assign diff_IQ = din_re - din_im;      // (I - Q)

    // ============================================================
    // 3. Constant Multiplication by 0.707 (181)
    // Result width is expanded (TOTAL_BIT + Q_format width)
    // This utilizes the efficient Shift-and-Add optimization in FPGA
    // ============================================================
    wire signed [TOTAL_BIT+FRAC_BIT:0] mult_sum, mult_diff;

    // The output width of multiplication is often 2*TOTAL_BIT, 
    // but here we only need enough width for safety before shifting.
    assign mult_sum  = sum_IQ  * COEFF_0_707;
    assign mult_diff = diff_IQ * COEFF_0_707;

    // ============================================================
    // 4. Output Logic & Truncation (Main State Machine)
    // ============================================================
    // All calculations include a division by 2^FRAC_BIT (right shift by FRAC_BIT)
    always @(*) begin
        dout_valid = in_valid;
        dout_re = 0; // Should ideally not be reached
        dout_im = 0;

        case (cnt_region)
            // -------------------------------------------------
            // W8^0 = 1 (Pass Through) - Covers trivial rotation cases
            // -------------------------------------------------
            3'b000, 3'b001, 3'b010, 3'b100, 3'b110: begin
                dout_re = din_re;
                dout_im = din_im;
            end

            // -------------------------------------------------
            // W8^1 = 0.707 - j0.707
            // Re = 0.707(I+Q), Im = 0.707(Q-I)
            // -------------------------------------------------
            3'b101: begin
                // Truncation: Right shift by FRAC_BIT to restore Q8.8 format
                dout_re = mult_sum[TOTAL_BIT+FRAC_BIT-1 : FRAC_BIT]; 
                
                // Im = -0.707(I-Q)
                // Note: Subtraction is handled by negating mult_diff
                dout_im = -mult_diff[TOTAL_BIT+FRAC_BIT-1 : FRAC_BIT]; 
            end

            // -------------------------------------------------
            // W8^2 = -j (Trivial Rotation)
            // Re = Q, Im = -I
            // -------------------------------------------------
            3'b011: begin
                dout_re = din_im;
                dout_im = ~din_re + 1'b1; // Negate I (Two's Complement)
            end

            // -------------------------------------------------
            // W8^3 = -0.707 - j0.707
            // Re = 0.707(Q-I), Im = -0.707(I+Q)
            // -------------------------------------------------
            3'b111: begin
                // Re = -0.707(I-Q)
                dout_re = -mult_diff[TOTAL_BIT+FRAC_BIT-1 : FRAC_BIT]; 
                
                // Im = -0.707(I+Q)
                dout_im = -mult_sum[TOTAL_BIT+FRAC_BIT-1 : FRAC_BIT];
            end
        endcase
    end

endmodule