module FFT_64 #(
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT  = 8
) (
    input clk,
    input rst_n,
    
    // Top Level Input (Natural Order)
    input FIFO_enable,
    input FFT_in_valid,
    input signed [TOTAL_BIT-1:0] FFT_in_re,
    input signed [TOTAL_BIT-1:0] FFT_in_im,

    // Top Level Output (Natural Order) 
    output wire FFT_out_ready, // Enable next block
    output reg  FFT_out_valid,
    output reg  signed [TOTAL_BIT-1:0] FFT_out_re,
    output reg  signed [TOTAL_BIT-1:0] FFT_out_im
);

    // ====================================================================
    //                             Parameters
    // ====================================================================
    localparam FFT_LENGTH       = 64;
    localparam FFT_STATE_BITS   = 2;
    localparam FFT_IDLE         = 2'd0;
    localparam FFT_CALCULATING  = 2'd1;
    localparam FFT_OUTPUT_REM   = 2'd2;

    // ====================================================================
    //                            Interconnects
    // ====================================================================
    
    // --- FSM Signals ---
    reg [5:0] FFT_cnt, FFT_cnt_n;
    reg [FFT_STATE_BITS-1:0] FFT_state, FFT_state_n;

    // --- Stage 1 Signals (N=64) ---
    wire signed [TOTAL_BIT-1:0] st1_in_r, st1_in_i;
    wire signed [TOTAL_BIT-1:0] st1_out_r, st1_out_i;
    wire        st1_valid;
    wire        st1_bf_mode;
    wire        PE_stage1_valid;

    // --- Trivial Rotation 1 (-j) Signals ---
    reg  [5:0]  cnt_d32;            // Delay counter for Stage 1 output
    wire        apply_neg_j_1;
    wire signed [TOTAL_BIT-1:0] st1_rot_r, st1_rot_i;

    // --- PIPELINE 1: Stage 1 -> Stage 2 ---
    reg  signed [TOTAL_BIT-1:0] st1_rot_r_FF, st1_rot_i_FF;
    reg         st1_valid_FF;
    reg         st2_bf_mode_FF;

    // --- Stage 2 Signals (N=32) ---
    wire        st2_bf_mode; // Combinational calc before FF
    wire signed [TOTAL_BIT-1:0] st2_out_r, st2_out_i;
    wire        st2_valid;

    // --- Trivial Rotation 2 (W8) Signals ---
    reg  [5:0]  cnt_d48;            // Latency counter
    wire [2:0]  cnt_region_stage2;
    wire        w8_valid;
    wire signed [TOTAL_BIT-1:0] st2_rot_r, st2_rot_i;

    // --- PIPELINE 2: Stage 2 -> Stage 3 ---
    reg  signed [TOTAL_BIT-1:0] st2_rot_r_FF, st2_rot_i_FF;
    reg         w8_valid_FF;

    // --- Stage 3 Signals (N=16) ---
    reg  [5:0]  cnt_st3_in;
    wire        st3_bf_mode;
    wire signed [TOTAL_BIT-1:0] st3_out_r, st3_out_i;
    wire        st3_valid;

    // --- Full Rotator (W64) Signals ---
    wire        rot_valid;
    wire signed [TOTAL_BIT-1:0] rot_out_r, rot_out_i;

    // --- Stage 4 Signals (N=8) ---
    reg  [5:0]  cnt_st4;
    wire        st4_bf_mode;
    wire signed [TOTAL_BIT-1:0] st4_out_r, st4_out_i;
    wire        st4_valid;

    // --- Trivial Rotation 3 (-j) Signals ---
    reg  [5:0]  cnt_st4_out;
    wire        apply_neg_j_2;
    wire signed [TOTAL_BIT-1:0] st4_rot_r, st4_rot_i;

    // --- PIPELINE 3: Stage 4 -> Stage 5 ---
    reg  signed [TOTAL_BIT-1:0] st4_rot_r_FF, st4_rot_i_FF;
    reg         st4_valid_FF;
    reg         st5_bf_mode_FF;

    // --- Stage 5 Signals (N=4) ---
    wire        st5_bf_mode; // Combinational calc before FF
    wire signed [TOTAL_BIT-1:0] st5_out_r, st5_out_i;
    wire        st5_valid;

    // --- Trivial Rotation 4 (W8) Signals ---
    reg  [5:0]  cnt_st5_out;
    wire        w8_2_valid;
    wire signed [TOTAL_BIT-1:0] st5_rot_r, st5_rot_i;

    // --- PIPELINE 4: Stage 5 -> Stage 6 ---
    reg  signed [TOTAL_BIT-1:0] st5_rot_r_FF, st5_rot_i_FF;
    reg         w8_2_valid_FF;

    // --- Stage 6 Signals (N=2) ---
    reg  [5:0]  cnt_st6;
    wire        st6_bf_mode;
    wire signed [TOTAL_BIT-1:0] st6_out_r, st6_out_i;
    wire        st6_valid;

    // ====================================================================
    //                         Finite State Machine
    // ====================================================================

    always @(*) begin
        FFT_state_n = FFT_state;
        FFT_cnt_n   = FFT_cnt;

        case (FFT_state)
            FFT_IDLE: begin
                FFT_cnt_n = 0;
                if (FFT_in_valid) begin
                    FFT_state_n = FFT_CALCULATING;
                end
            end
            FFT_CALCULATING: begin
                FFT_cnt_n = FFT_cnt + 1;
                if (FFT_cnt == FFT_LENGTH - 1) begin
                    FFT_state_n = FFT_IDLE;
                end
            end
            default: FFT_state_n = FFT_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (~rst_n) begin
            FFT_state <= FFT_IDLE;
            FFT_cnt   <= 0;
        end else begin
            FFT_state <= FFT_state_n;
            FFT_cnt   <= FFT_cnt_n;
        end
    end

    // ====================================================================
    //                       Group 1: Stages 1-3
    // ====================================================================

    // -------------------------------------------------------------
    // Stage 1 (N=64, Delay=32)
    // -------------------------------------------------------------
    assign st1_in_r = (FFT_in_valid) ? FFT_in_re : 0;
    assign st1_in_i = (FFT_in_valid) ? FFT_in_im : 0;
    
    assign st1_bf_mode     = FFT_cnt[5];
    assign PE_stage1_valid = (FFT_state == FFT_CALCULATING); 

    PE_radix23 #(.FIFO_LENGTH(32)) PE1 (
        .clk        (clk), 
        .rst_n      (rst_n),
        .FIFO_enable(FIFO_enable),
        .in_valid   (PE_stage1_valid), 
        .BF_mode    (st1_bf_mode),
        .din_re     (st1_in_r),  
        .din_im     (st1_in_i),
        .dout_valid (st1_valid), 
        .dout_re    (st1_out_r), 
        .dout_im    (st1_out_i)
    );

    // --- Trivial Rotation 1 (-j) ---
    
    always @(posedge clk) begin
        if (st1_valid) cnt_d32 <= cnt_d32 + 1; 
        else           cnt_d32 <= 0;
    end

    assign apply_neg_j_1 = (cnt_d32[5:4] == 2'b11); 

    assign st1_rot_r = (apply_neg_j_1) ? st1_out_i : st1_out_r;
    assign st1_rot_i = (apply_neg_j_1) ? (~st1_out_r + 1'b1) : st1_out_i;

    // --- PIPELINE 1: Stage 1 -> Stage 2 ---
    // Calculate control signal for next stage based on current counter
    assign st2_bf_mode = cnt_d32[4];

    always @(posedge clk) begin
        if (~rst_n) begin
            st1_valid_FF   <= 0;
            st2_bf_mode_FF <= 0;
            st1_rot_r_FF   <= 0;
            st1_rot_i_FF   <= 0;
        end else begin
            st1_valid_FF   <= st1_valid;
            st2_bf_mode_FF <= st2_bf_mode;
            st1_rot_r_FF   <= st1_rot_r;
            st1_rot_i_FF   <= st1_rot_i;
        end
    end

    // -------------------------------------------------------------
    // Stage 2 (N=32, Delay=16)
    // -------------------------------------------------------------
    PE_radix23 #(.FIFO_LENGTH(16)) PE2 (
        .clk        (clk), 
        .rst_n      (rst_n),
        .FIFO_enable(FIFO_enable),
        .in_valid   (st1_valid_FF),    // Use Pipeline 1 FF
        .BF_mode    (st2_bf_mode_FF),  // Use Pipeline 1 FF
        .din_re     (st1_rot_r_FF),    // Use Pipeline 1 FF
        .din_im     (st1_rot_i_FF),    // Use Pipeline 1 FF
        .dout_valid (st2_valid), 
        .dout_re    (st2_out_r), 
        .dout_im    (st2_out_i)
    );

    // --- Trivial Rotation 2 (W_8) ---
    
    always @(posedge clk) begin
        if (st2_valid) cnt_d48 <= cnt_d48 + 1; 
        else           cnt_d48 <= 0;
    end

    assign cnt_region_stage2 = cnt_d48[5:3];

    Rotator_W8 #(.TOTAL_BIT(TOTAL_BIT)) Rot_W8_G1 (
        .in_valid   (st2_valid),
        .cnt_region (cnt_region_stage2), 
        .din_re     (st2_out_r), 
        .din_im     (st2_out_i),
        .dout_valid (w8_valid), 
        .dout_re    (st2_rot_r), 
        .dout_im    (st2_rot_i)
    );

    // --- PIPELINE 2: Stage 2 -> Stage 3 ---
    always @(posedge clk) begin
        if (~rst_n) begin
            w8_valid_FF  <= 0;
            st2_rot_r_FF <= 0;
            st2_rot_i_FF <= 0;
        end else begin
            w8_valid_FF  <= w8_valid;
            st2_rot_r_FF <= st2_rot_r;
            st2_rot_i_FF <= st2_rot_i;
        end
    end

    // -------------------------------------------------------------
    // Stage 3 (N=16)
    // -------------------------------------------------------------
    // Counter runs on the delayed valid signal
    always @(posedge clk) begin
        if (w8_valid_FF) cnt_st3_in <= cnt_st3_in + 1; 
        else             cnt_st3_in <= 0;
    end

    assign st3_bf_mode = cnt_st3_in[3];

    PE_radix23 #(.FIFO_LENGTH(8)) PE3 (
        .clk        (clk), 
        .rst_n      (rst_n),
        .FIFO_enable(FIFO_enable),
        .in_valid   (w8_valid_FF),    // Use Pipeline 2 FF
        .BF_mode    (st3_bf_mode),
        .din_re     (st2_rot_r_FF),   // Use Pipeline 2 FF
        .din_im     (st2_rot_i_FF),   // Use Pipeline 2 FF
        .dout_valid (st3_valid), 
        .dout_re    (st3_out_r), 
        .dout_im    (st3_out_i)
    );

    // ====================================================================
    //                  Complex Multiplication (W_64)
    // ====================================================================
    
    Rotator #(.CNT_WIDTH(6)) Rot_Stage3 (
        .clk        (clk), 
        .rst_n      (rst_n), 
        .valid_in   (st3_valid), 
        .data_in_re (st3_out_r), 
        .data_in_im (st3_out_i),
        .valid_out  (rot_valid), 
        .data_out_re(rot_out_r), 
        .data_out_im(rot_out_i)
    );

    // ====================================================================
    //                       Group 2: Stages 4-6
    // ====================================================================

    // -------------------------------------------------------------
    // Stage 4 (N=8)
    // -------------------------------------------------------------
    always @(posedge clk) begin
        if (rot_valid) cnt_st4 <= cnt_st4 + 1; 
        else           cnt_st4 <= 0;
    end

    assign st4_bf_mode = cnt_st4[2];

    PE_radix23 #(.FIFO_LENGTH(4)) PE4 (
        .clk        (clk), 
        .rst_n      (rst_n),
        .FIFO_enable(FIFO_enable),
        .in_valid   (rot_valid), 
        .BF_mode    (st4_bf_mode), 
        .din_re     (rot_out_r), 
        .din_im     (rot_out_i),
        .dout_valid (st4_valid), 
        .dout_re    (st4_out_r), 
        .dout_im    (st4_out_i)
    );

    // --- Trivial Rotation 3 (-j) ---
    
    always @(posedge clk) begin
        if (st4_valid) cnt_st4_out <= cnt_st4_out + 1; 
        else           cnt_st4_out <= 0;
    end

    assign apply_neg_j_2 = (cnt_st4_out[2:1] == 2'b11); 

    assign st4_rot_r = (apply_neg_j_2) ? st4_out_i : st4_out_r;
    assign st4_rot_i = (apply_neg_j_2) ? (~st4_out_r + 1'b1) : st4_out_i;

    // --- PIPELINE 3: Stage 4 -> Stage 5 ---
    assign st5_bf_mode = cnt_st4_out[1];

    always @(posedge clk) begin
        if (~rst_n) begin
            st4_valid_FF   <= 0;
            st5_bf_mode_FF <= 0;
            st4_rot_r_FF   <= 0;
            st4_rot_i_FF   <= 0;
        end else begin
            st4_valid_FF   <= st4_valid;
            st5_bf_mode_FF <= st5_bf_mode;
            st4_rot_r_FF   <= st4_rot_r;
            st4_rot_i_FF   <= st4_rot_i;
        end
    end

    // -------------------------------------------------------------
    // Stage 5 (N=4)
    // -------------------------------------------------------------
    PE_radix23 #(.FIFO_LENGTH(2)) PE5 (
        .clk        (clk), 
        .rst_n      (rst_n),
        .FIFO_enable(FIFO_enable),
        .in_valid   (st4_valid_FF),    // Use Pipeline 3 FF
        .BF_mode    (st5_bf_mode_FF),  // Use Pipeline 3 FF
        .din_re     (st4_rot_r_FF),    // Use Pipeline 3 FF
        .din_im     (st4_rot_i_FF),    // Use Pipeline 3 FF
        .dout_valid (st5_valid), 
        .dout_re    (st5_out_r), 
        .dout_im    (st5_out_i)
    );

    // --- Trivial Rotation 4 (W_8) ---
    
    always @(posedge clk) begin
        if (st5_valid) cnt_st5_out <= cnt_st5_out + 1; 
        else           cnt_st5_out <= 0;
    end

    Rotator_W8 #(.TOTAL_BIT(TOTAL_BIT)) Rot_W8_G2 (
        .in_valid   (st5_valid),
        .cnt_region (cnt_st5_out[2:0]), 
        .din_re     (st5_out_r), 
        .din_im     (st5_out_i),
        .dout_valid (w8_2_valid), 
        .dout_re    (st5_rot_r), 
        .dout_im    (st5_rot_i)
    );

    // --- PIPELINE 4: Stage 5 -> Stage 6 ---
    always @(posedge clk) begin
        if (~rst_n) begin
            w8_2_valid_FF <= 0;
            st5_rot_r_FF  <= 0;
            st5_rot_i_FF  <= 0;
        end else begin
            w8_2_valid_FF <= w8_2_valid;
            st5_rot_r_FF  <= st5_rot_r;
            st5_rot_i_FF  <= st5_rot_i;
        end
    end

    // -------------------------------------------------------------
    // Stage 6 (N=2)
    // -------------------------------------------------------------
    // Counter runs on the delayed valid signal
    always @(posedge clk) begin
        if (w8_2_valid_FF) cnt_st6 <= cnt_st6 + 1; 
        else               cnt_st6 <= 0;
    end

    assign st6_bf_mode = cnt_st6[0];

    PE_radix23 #(.FIFO_LENGTH(1)) PE6 (
        .clk        (clk), 
        .rst_n      (rst_n),
        .FIFO_enable(FIFO_enable),
        .in_valid   (w8_2_valid_FF),  // Use Pipeline 4 FF
        .BF_mode    (st6_bf_mode),
        .din_re     (st5_rot_r_FF),   // Use Pipeline 4 FF
        .din_im     (st5_rot_i_FF),   // Use Pipeline 4 FF
        .dout_valid (st6_valid), 
        .dout_re    (st6_out_r), 
        .dout_im    (st6_out_i)
    );

    // ====================================================================
    //                          Output Logic
    // ====================================================================

    assign FFT_out_ready = st6_valid;

    always @(posedge clk) begin
        if (~rst_n) begin
            FFT_out_valid <= 0;
            FFT_out_re    <= 0;
            FFT_out_im    <= 0;
        end else begin
            FFT_out_re    <= st6_out_r;
            FFT_out_im    <= st6_out_i;
            FFT_out_valid <= FFT_out_ready;
        end
    end

endmodule