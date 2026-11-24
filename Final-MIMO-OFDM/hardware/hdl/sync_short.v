module sync_short #
(
    parameter FIFO_LENGTH = 32,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8,
    parameter THRESHOLD_SCALE = 128,
    parameter MIN_PLATEAU = 32
)
(
    input clk,
    input rst_n,
    input enable,

    input [TOTAL_BIT-1:0] sample_in_re,
    input [TOTAL_BIT-1:0] sample_in_im,

    output short_preamble_detected
);
// state parameters //
localparam STATE_BITS = 3;

localparam LSTF_IDLE = 3'd0;
localparam LSTF_DETECTING = 3'd1;
localparam LSTF_CHECKING = 3'd2;
localparam LSTF_DONE = 3'd3;
localparam LSTF_FINISH = 3'd4;

reg [STATE_BITS-1:0] LSTF_state, LSTF_state_n;

// parameters //
wire signed [TOTAL_BIT-1:0] mag_sq, mag_sq_avg;
wire signed [TOTAL_BIT-1:0]  sample_delayed_re,sample_delayed_im;
wire signed [TOTAL_BIT-1:0]  sample_delayed_conj_re, sample_delayed_conj_im;


wire signed [TOTAL_BIT-1:0] auto_re, auto_im;

wire signed [TOTAL_BIT-1:0] auto_re_avg, auto_im_avg;


wire signed [TOTAL_BIT-1:0] auto_norm;
wire auto_norm_valid;

reg signed [TOTAL_BIT-1:0] plateau_count;

// this is to ensure that the short preambles contains both positive and
// negative in-phase, to avoid raise false positives when there is a constant
// power
reg [TOTAL_BIT-1:0] pos_cnt, neg_cnt, pos_cnt_n, neg_cnt_n;

// ===================================================================
//                        1. Calculate |Z|^2
// ===================================================================

complex_to_mag_sq mag_sq_inst (

    .i(sample_in_re),
    .q(sample_in_im),

    .mag_sq(mag_sq)
);

// ===================================================================
//                 2.  Calculate Average Power
// ===================================================================

mv_avg #(
    .FIFO_LENGTH(16), .FIFO_WIDTH_LOG(4),
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
) 
mag_sq_avg_inst (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),

    .data_in(mag_sq),
    
    .data_out(mag_sq_avg),
    .data_out_valid()
);

// ===================================================================
//                3. Daley a STF Period (16 Cycle)
// ===================================================================

//----------------- Delay FIFO --------------------//
FIFO_delay_complex #(
    .FIFO_LENGTH(16),.FIFO_WIDTH_LOG(4),
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)  u_FIFO_delay_complex (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),

    .data_in_re(sample_in_re),
    .data_in_im(sample_in_im),

    .data_out_re(sample_delayed_re),
    .data_out_im(sample_delayed_im)
);

// ===================================================================
//              4. Autocorrealtion:  Z(n) x Z*(n-D)
// ===================================================================

assign sample_delayed_conj_re = sample_delayed_re;
assign sample_delayed_conj_im = ~sample_delayed_im+1;

complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
complex_mult_inst 
(
    .din_re(sample_in_re),
    .din_im(sample_in_im),
    .din_2_re(sample_delayed_conj_re),
    .din_2_im(sample_delayed_conj_im),

    .dout_re(auto_re),
    .dout_im(auto_im)
);

// ===================================================================
//                5. Soothing Curve (Moving Average)
// ===================================================================

mv_avg_dual_ch #(
    .FIFO_LENGTH(16), .FIFO_WIDTH_LOG(4),
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
mv_avg_dual_ch (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),

    .data_in0(auto_re),
    .data_in1(auto_im),

    .data_out0(auto_re_avg),
    .data_out1(auto_im_avg),
    .data_out_valid()
);

// ===================================================================
//               6. Calculate Autocorelation Magnitude
// ===================================================================

complex_to_mag#(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
) complex_to_mag (
    .i(auto_re_avg),
    .q(auto_im_avg),
    
    .mag(auto_norm)  
);

// ===================================================================
//                             7. FSM
// ===================================================================

wire has_pos = (pos_cnt > MIN_PLATEAU);
wire has_neg = (neg_cnt > MIN_PLATEAU);

wire [2*TOTAL_BIT-1:0] threshold_real;
wire [TOTAL_BIT-1:0] threshold_real_truncated;

assign threshold_real = (mag_sq_avg>>1);
assign threshold_real_truncated = threshold_real[TOTAL_BIT + FRAC_BIT - 1 : FRAC_BIT];

always @(*) begin
    LSTF_state_n = LSTF_state;
    pos_cnt_n = 0;
    neg_cnt_n = 0;
    case (LSTF_state)
        LSTF_IDLE: begin
            LSTF_state_n = (enable) ? LSTF_DETECTING : LSTF_IDLE; 
        end
        LSTF_DETECTING: begin
            LSTF_state_n = (auto_norm > (threshold_real_truncated>>>1) ) ? LSTF_CHECKING : LSTF_DETECTING;
        end
        LSTF_CHECKING: begin
            pos_cnt_n = (sample_in_re[TOTAL_BIT-1]) ? pos_cnt + 1 : pos_cnt;
            neg_cnt_n = (sample_in_re[TOTAL_BIT-1]) ? neg_cnt + 1 : neg_cnt;

            if (auto_norm < (threshold_real_truncated>>>1)) begin
                LSTF_state_n = LSTF_DETECTING;
            end
            else if (has_pos & has_neg) begin
                LSTF_state_n = LSTF_DONE;
            end
        end
        LSTF_DONE: begin
            LSTF_state_n = LSTF_FINISH;
        end
        LSTF_FINISH: begin
            LSTF_state_n = LSTF_FINISH;
        end
    endcase
end

assign short_preamble_detected = (LSTF_state == LSTF_DONE);


always @(posedge clk) begin
    if (~rst_n) begin
        LSTF_state <= LSTF_IDLE;

        pos_cnt <= 0;
        neg_cnt <= 0;        
    end 
    else begin
        LSTF_state <= LSTF_state_n;

        pos_cnt <= pos_cnt_n;
        neg_cnt <= neg_cnt_n;
    end
end

endmodule