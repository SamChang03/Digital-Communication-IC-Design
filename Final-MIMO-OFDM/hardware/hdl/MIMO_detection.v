module MIMO_detection #
(
    parameter FIFO_LENGTH = 32,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
)
(
    input clk,
    input rst_n,
    input MIMO_enable,
    input FFT_out_ready,
    // Channel Coefficients (H Matrix)
    input signed [TOTAL_BIT-1:0] FFT_out_A_re, // h_11
    input signed [TOTAL_BIT-1:0] FFT_out_A_im,
    input signed [TOTAL_BIT-1:0] FFT_out_B_re, // h_21 (TX A -> RX B)
    input signed [TOTAL_BIT-1:0] FFT_out_B_im,

    input signed [TOTAL_BIT-1:0] inv_channel_in_AA_re, // h_11
    input signed [TOTAL_BIT-1:0] inv_channel_in_AA_im,
    input signed [TOTAL_BIT-1:0] inv_channel_in_AB_re, // h_21 (TX A -> RX B)
    input signed [TOTAL_BIT-1:0] inv_channel_in_AB_im,
    input signed [TOTAL_BIT-1:0] inv_channel_in_BA_re, // h_12 (TX B -> RX A)
    input signed [TOTAL_BIT-1:0] inv_channel_in_BA_im,
    input signed [TOTAL_BIT-1:0] inv_channel_in_BB_re, // h_22
    input signed [TOTAL_BIT-1:0] inv_channel_in_BB_im,

    output reg signed [TOTAL_BIT-1:0] RX_A_estimated_re,
    output reg signed [TOTAL_BIT-1:0] RX_A_estimated_im,
    output reg signed [TOTAL_BIT-1:0] RX_B_estimated_re,
    output reg signed [TOTAL_BIT-1:0] RX_B_estimated_im,

    output reg MIMO_detection_valid,
    output reg MIMO_detection_ready
);

// =================================================//
//                       FSM                        //
// =================================================//
localparam MIMO_STATE_BIT = 2;
localparam MIMO_CNT_BIT = 6;
localparam FFT_LENGTH = 64;

localparam MIMO_IDLE = 2'd0;
localparam MIMO_LOAD_INV_CHANNEL = 2'd1;
localparam MIMO_WAIT_FFT_VALID = 2'd2;
localparam MIMO_OPERATING = 2'd3; // 1. Load FFT input 2.calcuate estimated 

//localparam MIMO_OPERATING = 4;

reg [MIMO_STATE_BIT-1:0] MIMO_state, MIMO_state_n;
reg [MIMO_CNT_BIT-1:0] MIMO_cnt, MIMO_cnt_n ;

reg mem_wr_en;

always @(*) begin
    MIMO_state_n = MIMO_state;
    MIMO_cnt_n = MIMO_cnt;
    MIMO_detection_ready = 0;
    mem_wr_en = 0;
    
    case (MIMO_state)
        MIMO_IDLE:begin
            MIMO_cnt_n = 0;
            if (MIMO_enable) begin
                MIMO_state_n = MIMO_LOAD_INV_CHANNEL;
            end
        end
        MIMO_LOAD_INV_CHANNEL: begin
            MIMO_cnt_n = MIMO_cnt +1;
            mem_wr_en = 1;
            if (MIMO_cnt == FFT_LENGTH-1) begin
                MIMO_cnt_n = 0;
                MIMO_state_n = MIMO_WAIT_FFT_VALID;
            end
        end
        MIMO_WAIT_FFT_VALID: begin
            MIMO_cnt_n = 0;
            if (FFT_out_ready) begin
                MIMO_state_n = MIMO_OPERATING;
            end
        end
        MIMO_OPERATING: begin
            MIMO_cnt_n = MIMO_cnt +1;
            MIMO_detection_ready = 1;
            if (MIMO_cnt == FFT_LENGTH-1) begin
                MIMO_state_n = MIMO_WAIT_FFT_VALID;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (~rst_n) begin
        MIMO_state <= MIMO_IDLE;
        MIMO_cnt <= 0;
    end
    else begin
        MIMO_state <= MIMO_state_n;
        MIMO_cnt <= MIMO_cnt_n;
    end
end

reg [MIMO_CNT_BIT-1:0] MIMO_cnt_bitreverse;

integer i;
always @(*) begin
    for ( i=0 ; i< MIMO_CNT_BIT; i=i+1 ) begin
        MIMO_cnt_bitreverse[i] = MIMO_cnt[(MIMO_CNT_BIT-1)-i];
    end
end

// =================================================//
//                   Zero-Forcing                   //
// =================================================//

wire [TOTAL_BIT-1:0] RX_A_est_1_re_FF, RX_A_est_1_im_FF;
wire [TOTAL_BIT-1:0] RX_A_est_2_re_FF, RX_A_est_2_im_FF;

wire [TOTAL_BIT-1:0] RX_B_est_1_re_FF, RX_B_est_1_im_FF;
wire [TOTAL_BIT-1:0] RX_B_est_2_re_FF, RX_B_est_2_im_FF;

wire [TOTAL_BIT-1:0] RX_A_estimated_re_FF, RX_A_estimated_im_FF;
wire [TOTAL_BIT-1:0] RX_B_estimated_re_FF, RX_B_estimated_im_FF;

// -------------------------------------------------------------//
// RX_A_estimated = inv_channel_AA* RX_A  + inv_channel_BA*RX_B
// -------------------------------------------------------------//
wire [TOTAL_BIT-1:0] inv_channel_cal_AA_re, inv_channel_cal_AA_im,
                     inv_channel_cal_AB_re, inv_channel_cal_AB_im,
                     inv_channel_cal_BA_re, inv_channel_cal_BA_im,
                     inv_channel_cal_BB_re, inv_channel_cal_BB_im;

complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
complex_mult_1 
(
    .din_re(FFT_out_A_re),
    .din_im(FFT_out_A_im),
    .din_2_re(inv_channel_cal_AA_re),
    .din_2_im(inv_channel_cal_AA_im),

    .dout_re(RX_A_est_1_re_FF),
    .dout_im(RX_A_est_1_im_FF)
);

complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
complex_mult_2 
(
    .din_re(FFT_out_B_re),
    .din_im(FFT_out_B_im),
    .din_2_re(inv_channel_cal_BA_re),
    .din_2_im(inv_channel_cal_BA_im),

    .dout_re(RX_A_est_2_re_FF),
    .dout_im(RX_A_est_2_im_FF)
);

// Complex Adder
complex_add #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) add_1 (
    .a_re(RX_A_est_1_re_FF), .a_im(RX_A_est_1_im_FF),
    .b_re(RX_A_est_2_re_FF), .b_im(RX_A_est_2_im_FF),

    .y_re(RX_A_estimated_re_FF), .y_im(RX_A_estimated_im_FF)
);

// -------------------------------------------------------------//
// RX_B_estimated = inv_channel_AB* RX_A  + inv_channel_BB*RX_B
// -------------------------------------------------------------//
complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
complex_mult_3 
(
    .din_re(FFT_out_A_re),
    .din_im(FFT_out_A_im),
    .din_2_re(inv_channel_cal_AB_re),
    .din_2_im(inv_channel_cal_AB_im),

    .dout_re(RX_B_est_1_re_FF),
    .dout_im(RX_B_est_1_im_FF)
);

complex_mult #(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
)
complex_mult_4 
(
    .din_re(FFT_out_B_re),
    .din_im(FFT_out_B_im),
    .din_2_re(inv_channel_cal_BB_re),
    .din_2_im(inv_channel_cal_BB_im),

    .dout_re(RX_B_est_2_re_FF),
    .dout_im(RX_B_est_2_im_FF)
);

// Complex Adder
complex_add #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) add_2 (
    .a_re(RX_B_est_1_re_FF), .a_im(RX_B_est_1_im_FF),
    .b_re(RX_B_est_2_re_FF), .b_im(RX_B_est_2_im_FF),

    .y_re(RX_B_estimated_re_FF), .y_im(RX_B_estimated_im_FF)
);


// -------------------------------------------------------------//
//                         Output FF
// -------------------------------------------------------------//

always @(posedge clk) begin
    // Control valid
    if (~rst_n) begin
        MIMO_detection_valid <= 0;
    end
    else begin
        MIMO_detection_valid <= MIMO_detection_ready; 
    end

    RX_A_estimated_re <= RX_A_estimated_re_FF;
    RX_A_estimated_im <= RX_A_estimated_im_FF;

    RX_B_estimated_re <= RX_B_estimated_re_FF;
    RX_B_estimated_im <= RX_B_estimated_im_FF;
end
// ===================== Output Buffer for FFT reversed =====================//



// ===================== Channel Memory =====================//

// INV AA
channel_mem #(
    .FIFO_LENGTH(FFT_LENGTH),.TOTAL_BIT(TOTAL_BIT),.ADDR_BIT(MIMO_CNT_BIT)
) inv_channel_mem_AA (
    .clk(clk),
    
    .write_en(mem_wr_en),
    .write_addr(MIMO_cnt),
    .data_in_re(inv_channel_in_AA_re),.data_in_im(inv_channel_in_AA_im),

    .read_addr(MIMO_cnt_bitreverse),
    .data_out_re(inv_channel_cal_AA_re),.data_out_im(inv_channel_cal_AA_im)
);
// INV AB
channel_mem #(
    .FIFO_LENGTH(FFT_LENGTH),.TOTAL_BIT(TOTAL_BIT),.ADDR_BIT(MIMO_CNT_BIT)
) inv_channel_mem_AB (
    .clk(clk),
    
    .write_en(mem_wr_en),
    .write_addr(MIMO_cnt),
    .data_in_re(inv_channel_in_AB_re),.data_in_im(inv_channel_in_AB_im),

    .read_addr(MIMO_cnt_bitreverse),
    .data_out_re(inv_channel_cal_AB_re),.data_out_im(inv_channel_cal_AB_im)
);
// INV BA
channel_mem #(
    .FIFO_LENGTH(FFT_LENGTH),.TOTAL_BIT(TOTAL_BIT),.ADDR_BIT(MIMO_CNT_BIT)
) inv_channel_mem_BA (
    .clk(clk),
    
    .write_en(mem_wr_en),
    .write_addr(MIMO_cnt),
    .data_in_re(inv_channel_in_BA_re),.data_in_im(inv_channel_in_BA_im),

    .read_addr(MIMO_cnt_bitreverse),
    .data_out_re(inv_channel_cal_BA_re),.data_out_im(inv_channel_cal_BA_im)
);
//INV BB
channel_mem #(
    .FIFO_LENGTH(FFT_LENGTH),
    .TOTAL_BIT(TOTAL_BIT),
    .ADDR_BIT(MIMO_CNT_BIT)
) inv_channel_mem_BB (
    .clk(clk),
    
    .write_en(mem_wr_en),
    .write_addr(MIMO_cnt),
    .data_in_re(inv_channel_in_BB_re),.data_in_im(inv_channel_in_BB_im),

    .read_addr(MIMO_cnt_bitreverse),
    .data_out_re(inv_channel_cal_BB_re),.data_out_im(inv_channel_cal_BB_im)
);

endmodule