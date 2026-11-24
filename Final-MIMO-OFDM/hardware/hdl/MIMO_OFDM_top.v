module MIMO_OFDM_top #
(
    parameter FIFO_LENGTH = 32,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
)
(
    input clk,
    input rst_n,
    input MIMO_OFDM_enable,
    // Channel Coefficients (H Matrix)
    input signed [TOTAL_BIT-1:0] RX_A_re,
    input signed [TOTAL_BIT-1:0] RX_A_im,
    input signed [TOTAL_BIT-1:0] RX_B_re,
    input signed [TOTAL_BIT-1:0] RX_B_im,


    output MIMO_OFDM_valid,
    output [1:0] bits_demapping_A,
    output [1:0] bits_demapping_B
);

// =================================================//
//                 Wire Connection                  //
// =================================================//

wire short_enable, long_enable, FFT_in_valid;
wire short_preamble_detected, long_preamble_detected;
wire MIMO_enable;

// =================================================//
//                     Input FF                     //
// =================================================//
reg signed [TOTAL_BIT-1:0] RX_A_re_FF, RX_A_im_FF,
                           RX_B_re_FF, RX_B_im_FF;
always @(posedge clk) begin
    RX_A_re_FF <= RX_A_re;
    RX_A_im_FF <= RX_A_im;
    RX_B_re_FF <= RX_B_re;
    RX_B_im_FF <= RX_B_im;
end

// =================================================//
//          Global Finite State Machine (FSM)       //
// =================================================//
localparam TOP_STATE_BIT = 4;
localparam GLOBAL_CNT_BIT = 9;
localparam FFT_LENGTH = 64;
localparam CP_LENGTH = 16;

top_FSM u_TOP_FSM (
    .clk(clk),
    .rst_n(rst_n),
    .MIMO_OFDM_enable(MIMO_OFDM_enable),
    .short_preamble_detected(short_preamble_detected),
    .long_preamble_detected(long_preamble_detected),

    .short_enable(short_enable),
    .long_enable(long_enable),
    .FFT_in_valid(FFT_in_valid)
);

// =================================================//
//               Frame Detection  (L-STF)           //
// =================================================//

sync_short #
(
    .FIFO_LENGTH(),
    .FIFO_WIDTH_LOG(),
    .TOTAL_BIT(),
    .FRAC_BIT(),
    .MIN_PLATEAU(),
    .THRESHOLD_SCALE() 
)
sync_short 
(
    .clk(clk),
    .rst_n(rst_n),
    .enable(short_enable),

    .sample_in_re(RX_A_re_FF),
    .sample_in_im(RX_A_im_FF),

    .short_preamble_detected(short_preamble_detected)
);

// =================================================//
//               Synchronizatio  (L-LTF)            //
// =================================================//

sync_long #
(
    .FIFO_LENGTH(),
    .FIFO_WIDTH_LOG(),
    .TOTAL_BIT(),
    .FRAC_BIT()
)
sync_long 
(
    .clk(clk),
    .rst_n(rst_n),
    .enable(long_enable),

    .sample_in_re(RX_A_re_FF),
    .sample_in_im(RX_A_im_FF),

    .long_preamble_detected(long_preamble_detected)
);

// =================================================//
//             Fast Fourier Transform (FFT)         //
// =================================================//

wire signed [TOTAL_BIT-1:0] FFT_out_A_re, FFT_out_A_im,
                            FFT_out_B_re, FFT_out_B_im;


FFT_64 #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) FFT_RX_A (
    .clk(clk),
    .rst_n(rst_n),
    .FIFO_enable(MIMO_OFDM_enable),
    .FFT_in_valid(FFT_in_valid),
    .FFT_in_re(RX_A_re_FF),
    .FFT_in_im(RX_A_im_FF),
    .FFT_out_ready(FFT_out_ready), // Enable next block, a clock head data
    .FFT_out_valid(FFT_out_valid),
    .FFT_out_re(FFT_out_A_re),
    .FFT_out_im(FFT_out_A_im)
);

FFT_64 #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) FFT_RX_B (
    .clk(clk),
    .rst_n(rst_n),
    .FIFO_enable(MIMO_OFDM_enable),
    .FFT_in_valid(FFT_in_valid),
    .FFT_in_re(RX_B_re),
    .FFT_in_im(RX_B_im),
    //.FFT_out_ready(), // Enable next block, a clock head data
    //.FFT_out_valid(),
    .FFT_out_re(FFT_out_B_re),
    .FFT_out_im(FFT_out_B_im)
);

// =================================================//
//            Channel Estimation (HT-LTF)           //
// =================================================//

wire signed [TOTAL_BIT-1:0] channel_AA_re, channel_AA_im,
                            channel_AB_re, channel_AB_im,
                            channel_BA_re, channel_BA_im,
                            channel_BB_re, channel_BB_im;
wire channel_valid;

channel_est  u_channel_est (
    .clk(clk),
    .rst_n(rst_n),
    .FFT_out_ready(FFT_out_ready),
    .FFT_out_valid(FFT_out_valid),

    .data_in_re_AntennaA(FFT_out_A_re),
    .data_in_im_AntennaA(FFT_out_A_im),
    .data_in_re_AntennaB(FFT_out_B_re),
    .data_in_im_AntennaB(FFT_out_B_im),

    .channel_out_AA_re(channel_AA_re), .channel_out_AA_im(channel_AA_im),
    .channel_out_AB_re(channel_AB_re), .channel_out_AB_im(channel_AB_im),
    .channel_out_BA_re(channel_BA_re), .channel_out_BA_im(channel_BA_im),
    .channel_out_BB_re(channel_BB_re), .channel_out_BB_im(channel_BB_im),
    .channel_valid(channel_valid) 
);

// =================================================//
//        Channel Prepocessing (Zero-Forcing)       //
// =================================================//

wire signed [TOTAL_BIT-1:0] inv_channel_AA_re, inv_channel_AA_im,
                            inv_channel_AB_re, inv_channel_AB_im,
                            inv_channel_BA_re, inv_channel_BA_im,
                            inv_channel_BB_re, inv_channel_BB_im;

wire inv_channel_valid;
channel_prepocessing  u_channel_prepocessing (
    .clk(clk),
    .rst_n(rst_n),
    .enable(channel_valid), 

    .channel_AA_re(channel_AA_re), .channel_AA_im(channel_AA_im),
    .channel_AB_re(channel_AB_re), .channel_AB_im(channel_AB_im),
    .channel_BA_re(channel_BA_re), .channel_BA_im(channel_BA_im),
    .channel_BB_re(channel_BB_re), .channel_BB_im(channel_BB_im),

    .inv_channel_AA_re(inv_channel_AA_re), .inv_channel_AA_im(inv_channel_AA_im),
    .inv_channel_AB_re(inv_channel_AB_re), .inv_channel_AB_im(inv_channel_AB_im),
    .inv_channel_BA_re(inv_channel_BA_re), .inv_channel_BA_im(inv_channel_BA_im),
    .inv_channel_BB_re(inv_channel_BB_re), .inv_channel_BB_im(inv_channel_BB_im),

    .channel_prepocessing_valid(inv_channel_valid) // Enable next block, a clock head data
);

// =================================================//
//           MIMO Detection (Zero-Forcing)          //
// =================================================//

assign MIMO_enable = inv_channel_valid;
wire MIMO_detection_valid;

wire signed [TOTAL_BIT-1:0] RX_A_estimated_re, RX_A_estimated_im,
                            RX_B_estimated_re, RX_B_estimated_im;

MIMO_detection u_MIMO(
    .clk(clk),
    .rst_n(rst_n),
    .MIMO_enable(MIMO_enable),
    .FFT_out_ready(FFT_out_ready),

    .FFT_out_A_re(FFT_out_A_re), .FFT_out_A_im(FFT_out_A_im),
    .FFT_out_B_re(FFT_out_B_re), .FFT_out_B_im(FFT_out_B_im),

    .inv_channel_in_AA_re(inv_channel_AA_re), .inv_channel_in_AA_im(inv_channel_AA_im),
    .inv_channel_in_AB_re(inv_channel_AB_re), .inv_channel_in_AB_im(inv_channel_AB_im),
    .inv_channel_in_BA_re(inv_channel_BA_re), .inv_channel_in_BA_im(inv_channel_BA_im),
    .inv_channel_in_BB_re(inv_channel_BB_re), .inv_channel_in_BB_im(inv_channel_BB_im),

    .RX_A_estimated_re(RX_A_estimated_re), .RX_A_estimated_im(RX_A_estimated_im),
    .RX_B_estimated_re(RX_B_estimated_re), .RX_B_estimated_im(RX_B_estimated_im),

    .MIMO_detection_valid(MIMO_detection_valid),
    .MIMO_detection_ready(MIMO_detection_ready)
);

// =================================================//
//                Two Ping Pong Buffer              //
// =================================================//
wire signed [TOTAL_BIT-1:0] RX_A_serial_out_re, RX_A_serial_out_im,
                            RX_B_serial_out_re, RX_B_serial_out_im;

ping_pong_buffer #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) PP_BUFFER_RXA (
    .clk(clk),
    .rst_n(rst_n),
    .MIMO_detection_valid(MIMO_detection_valid),
    .MIMO_detection_ready(MIMO_detection_ready),
    .RX_estimated_re(RX_A_estimated_re),
    .RX_estimated_im(RX_A_estimated_im),

    .serial_out_valid(serial_out_valid),
    .serial_out_re(RX_A_serial_out_re),
    .serial_out_im(RX_A_serial_out_im)
);

ping_pong_buffer #(
    .TOTAL_BIT(TOTAL_BIT),
    .FRAC_BIT(FRAC_BIT)
) PP_BUFFER_RXB (
    .clk(clk),
    .rst_n(rst_n),
    .MIMO_detection_valid(MIMO_detection_valid),
    .MIMO_detection_ready(MIMO_detection_ready),
    .RX_estimated_re(RX_B_estimated_re),
    .RX_estimated_im(RX_B_estimated_im),

    //.serial_out_valid(),
    .serial_out_re(RX_B_serial_out_re),
    .serial_out_im(RX_B_serial_out_im)
);

// =================================================//
//                QAM Demapping (QKSP)              //
// =================================================//

wire QAM_valid = serial_out_valid;
wire QAM_ready;
assign MIMO_OFDM_valid = QAM_ready;

QAM_demap u_QPSK_RXA
(
	.clk(clk),
	.rst_n(rst_n),
	.QAM_in_re(RX_A_serial_out_re),
	.QAM_in_im(RX_A_serial_out_im),
	.QAM_valid(QAM_valid),

	.QAM_ready(QAM_ready),
	.QAM_out_bit(bits_demapping_A)
);

QAM_demap u_QPSK_RXB
(
	.clk(clk),
	.rst_n(rst_n),
	.QAM_in_re(RX_B_serial_out_re),
	.QAM_in_im(RX_B_serial_out_im),
	.QAM_valid(QAM_valid),

	//.QAM_ready(),
	.QAM_out_bit(bits_demapping_B)
);

endmodule