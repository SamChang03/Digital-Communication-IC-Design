module top_FSM (
    // Global Control
    input  wire       clk,
    input  wire       rst_n,

    // Control Inputs
    input  wire       MIMO_OFDM_enable,
    input  wire       short_preamble_detected,
    input  wire       long_preamble_detected,

    // FSM Outputs
    output reg        short_enable,
    output reg        long_enable,
    output reg        FFT_in_valid
);

    // =================================================================
    // Parameters & State Encoding
    // =================================================================
    localparam TOP_STATE_BIT = 4;
    localparam GLOBAL_CNT_BIT = 9;
    localparam FFT_LENGTH = 64;
    localparam CP_LENGTH = 16;

    localparam TOP_IDLE                      = 4'd0;
    localparam TOP_FRAME_DETECT              = 4'd1;
    localparam TOP_WAITE_LEGACY_LTS          = 4'd2;
    localparam TOP_FINE_SYNC                 = 4'd3;
    localparam TOP_WAITE_HT_LTS              = 4'd4;
    localparam TOP_CHANNEL_ESTIMATION_FIRST  = 4'd5;
    localparam TOP_WAITE_HT_LTS_SECOND       = 4'd6;
    localparam TOP_CHANNEL_ESTIMATION_SECOND = 4'd7;
    localparam TOP_CHANNEL_PREPROCESSING     = 4'd8;
    localparam TOP_MIMO_DETECTION            = 4'd9;

    // =================================================================
    // Internal Registers
    // =================================================================
    reg [TOP_STATE_BIT-1:0]  top_state, top_state_n;
    reg [GLOBAL_CNT_BIT-1:0] global_cnt, global_cnt_n;
    reg [1:0]                LTC_peak_cnt, LTC_peak_cnt_n;

    // Assign current state to output (for debugging)
    assign current_state = top_state;

    // =================================================================
    // Combinational Logic (Next State & Output Logic)
    // =================================================================
    always @(*) begin
        // Default assignments to prevent latches
        top_state_n    = top_state;
        global_cnt_n   = 0;
        LTC_peak_cnt_n = 0;

        short_enable   = 1;
        long_enable    = 0;
        FFT_in_valid   = 0; 

        case (top_state)
            TOP_IDLE: begin
                global_cnt_n = 0;
                if (MIMO_OFDM_enable) begin
                    top_state_n = TOP_FRAME_DETECT;
                end
            end

            TOP_FRAME_DETECT: begin
                short_enable = 1;
                if (short_preamble_detected) begin
                    top_state_n = TOP_WAITE_LEGACY_LTS;
                end
            end

            TOP_WAITE_LEGACY_LTS: begin
                short_enable = 1;
                global_cnt_n = global_cnt + 1;
                if (global_cnt == 100) begin
                    top_state_n = TOP_FINE_SYNC;
                end
            end

            TOP_FINE_SYNC: begin
                long_enable = 1;
                LTC_peak_cnt_n = LTC_peak_cnt;
                
                if (long_preamble_detected) begin
                    LTC_peak_cnt_n = LTC_peak_cnt + 1;
                end
                
                if (LTC_peak_cnt == 2) begin
                    top_state_n = TOP_WAITE_HT_LTS;
                end
            end

            TOP_WAITE_HT_LTS: begin
                long_enable = 1;
                global_cnt_n = global_cnt + 1;
                if (global_cnt == CP_LENGTH*12-4) begin
                    global_cnt_n = 0;
                    top_state_n = TOP_CHANNEL_ESTIMATION_FIRST;
                end
            end

            TOP_CHANNEL_ESTIMATION_FIRST: begin
                FFT_in_valid = (global_cnt < FFT_LENGTH+1) ? 1 : 0;
                global_cnt_n = global_cnt + 1;
                if (global_cnt == CP_LENGTH*6-1) begin
                    global_cnt_n = 0;
                    top_state_n = TOP_WAITE_HT_LTS_SECOND;
                end
            end

            TOP_WAITE_HT_LTS_SECOND: begin
                global_cnt_n = global_cnt + 1;
                if (global_cnt == FFT_LENGTH-1) begin
                    global_cnt_n = 0;
                    top_state_n = TOP_CHANNEL_ESTIMATION_SECOND;
                end
            end

            TOP_CHANNEL_ESTIMATION_SECOND: begin
                FFT_in_valid = (global_cnt < FFT_LENGTH+1) ? 1 : 0;
                global_cnt_n = global_cnt + 1;
                if (global_cnt == CP_LENGTH*6-1) begin
                    FFT_in_valid = 0;
                    global_cnt_n = 0;
                    top_state_n = TOP_CHANNEL_PREPROCESSING;
                end
            end

            TOP_CHANNEL_PREPROCESSING: begin
                global_cnt_n = global_cnt + 1;
                if (global_cnt == CP_LENGTH*3-1) begin
                    global_cnt_n = 0;
                    top_state_n = TOP_MIMO_DETECTION;
                end
            end

            TOP_MIMO_DETECTION: begin
                FFT_in_valid = 0;
                global_cnt_n = global_cnt + 1;
                
                if (global_cnt < FFT_LENGTH+1) begin
                    FFT_in_valid = 1;
                end

                if (global_cnt == FFT_LENGTH+16-1) begin
                    global_cnt_n = 0;
                end
            end
            
            default: begin
                top_state_n = TOP_IDLE;
            end
        endcase
    end

    // =================================================================
    // Sequential Logic (Flip-Flops)
    // =================================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            top_state    <= TOP_IDLE;
            global_cnt   <= 0;
            LTC_peak_cnt <= 0;
        end
        else begin
            top_state    <= top_state_n;
            global_cnt   <= global_cnt_n;
            LTC_peak_cnt <= LTC_peak_cnt_n;
        end
    end

endmodule