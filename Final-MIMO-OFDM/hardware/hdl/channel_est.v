module channel_est #
(
    parameter FIFO_LENGTH = 32,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8,
    parameter ADDR_BIT = 6
)
(
    input clk,
    input rst_n,
    input FFT_out_ready,
    input FFT_out_valid,

    input signed [TOTAL_BIT-1:0] data_in_re_AntennaA, // RX A
    input signed [TOTAL_BIT-1:0] data_in_im_AntennaA,
    input signed [TOTAL_BIT-1:0] data_in_re_AntennaB, // RX Bs
    input signed [TOTAL_BIT-1:0] data_in_im_AntennaB,

    output signed [TOTAL_BIT-1:0] channel_out_AA_re, // TX A -> RX A
    output signed [TOTAL_BIT-1:0] channel_out_AA_im,

    output signed [TOTAL_BIT-1:0] channel_out_AB_re, // TX A -> RX B
    output signed [TOTAL_BIT-1:0] channel_out_AB_im,

    output signed [TOTAL_BIT-1:0] channel_out_BA_re, // TX B -> RX A
    output signed [TOTAL_BIT-1:0] channel_out_BA_im,

    output signed [TOTAL_BIT-1:0] channel_out_BB_re, // TX B -> RX B
    output signed [TOTAL_BIT-1:0] channel_out_BB_im,

    output reg channel_valid
);

reg order; // order 0: first estimation; order 1: second estimation;
reg signed [TOTAL_BIT-1:0] channel_AA_re, channel_AA_im,
                           channel_AB_re, channel_AB_im,
                           channel_BA_re, channel_BA_im,
                           channel_BB_re, channel_BB_im;

//========================= FSM ===============================//
localparam FFT_LENGTH = 64;

localparam CHANNEL_STATE_BIT = 3;
localparam CHANNEL_CNT_BIT = 6;

localparam CHANNEL_ESTIMATE_IDLE = 3'd0;
localparam CHANNEL_ESTIMATE_LOADING_FIRST = 3'd1;
localparam CHANNEL_WAIT_SECOND_HT_LTS = 3'd2;
localparam CHANNEL_ESTIMATE_LOADING_SECOND = 3'd3;
localparam CHANNEL_ESTIMATE_WAIT_PROCESSING = 3'd4;
localparam CHANNEL_ESTIMATE_SENDING_DATA = 3'd5;
localparam CHANNEL_ESTIMATE_DONE= 3'd6;

reg [CHANNEL_STATE_BIT-1:0] channel_est_state, channel_est_state_n;
reg [CHANNEL_CNT_BIT-1:0] channel_est_cnt, channel_est_cnt_n ;

always @(*) begin
    order = 0;
    channel_valid = 0;

    channel_est_state_n = channel_est_state;
    channel_est_cnt_n = channel_est_cnt;
    case (channel_est_state)
        CHANNEL_ESTIMATE_IDLE: begin
            channel_est_state_n = (FFT_out_ready) ? CHANNEL_ESTIMATE_LOADING_FIRST : channel_est_state;
        end
        CHANNEL_ESTIMATE_LOADING_FIRST: begin
            channel_est_cnt_n = channel_est_cnt+1;
            if (channel_est_cnt == FFT_LENGTH-1) begin
                channel_est_cnt_n = 0;
                channel_est_state_n = CHANNEL_WAIT_SECOND_HT_LTS;
            end
        end
        CHANNEL_WAIT_SECOND_HT_LTS: begin
            channel_est_state_n = CHANNEL_WAIT_SECOND_HT_LTS;
            channel_est_cnt_n = channel_est_cnt +1;
            if (FFT_out_ready && channel_est_cnt == (FFT_LENGTH/2 -1)) begin
                channel_est_cnt_n = 0;
                channel_est_state_n = CHANNEL_ESTIMATE_LOADING_SECOND;
            end
            else if (channel_est_cnt == (FFT_LENGTH/2 -1)) begin
                channel_est_cnt_n = channel_est_cnt;
            end
        end
        CHANNEL_ESTIMATE_LOADING_SECOND: begin
            order = 1;
            channel_est_cnt_n = channel_est_cnt+1;
            if (channel_est_cnt == FFT_LENGTH-1) begin
                channel_est_cnt_n = 0;
                channel_est_state_n = CHANNEL_ESTIMATE_WAIT_PROCESSING;
            end            
        end
        CHANNEL_ESTIMATE_WAIT_PROCESSING: begin
            channel_est_state_n = CHANNEL_ESTIMATE_SENDING_DATA;
            channel_est_cnt_n = 0; 
        end
        CHANNEL_ESTIMATE_SENDING_DATA: begin
            channel_valid = 1;
            channel_est_cnt_n = channel_est_cnt+1;
            if (channel_est_cnt == FFT_LENGTH-1) begin
                channel_est_cnt_n = 0;
                channel_est_state_n = CHANNEL_ESTIMATE_DONE;
            end   
        end
        
    endcase
end

always @(posedge clk) begin
    if (~rst_n) begin
        channel_est_state <= CHANNEL_ESTIMATE_IDLE;
        channel_est_cnt <= 0;
    end
    else begin
        channel_est_state <= channel_est_state_n;
        channel_est_cnt <= channel_est_cnt_n;
    end
end

//==================== Bits Reverse From FFT ===========================//
reg [CHANNEL_CNT_BIT-1:0] mem_addr;

integer i;
always @(*) begin
    for ( i=0 ; i< CHANNEL_CNT_BIT; i=i+1 ) begin
        mem_addr[i] = channel_est_cnt[(CHANNEL_CNT_BIT-1)-i];
    end
end

//------------------- LTS_Chips LUT -------------------------//
// 0 --> -1 change sign
// 1 --> 1 no change
localparam [FFT_LENGTH-1:0] LTS_SEQUENCE = 
    64'b0101110101110110_1101010011101111_1111101110100101_1101101110101110;

wire odd = (mem_addr[0]);
wire first_est = ~order;

wire no_change = (LTS_SEQUENCE[mem_addr] == 1);

always @(*) begin
    channel_AA_re = 0; channel_AA_im = 0;
    channel_AB_re = 0; channel_AB_im = 0;
    channel_BA_re = 0; channel_BA_im = 0;
    channel_BB_re = 0; channel_BB_im = 0;
    if (FFT_out_valid) begin
        case ({first_est,odd})
            2'b00: begin
                channel_AA_re = (no_change) ? data_in_re_AntennaA : ~data_in_re_AntennaA+1;
                channel_AA_im = (no_change) ? data_in_im_AntennaA : ~data_in_im_AntennaA+1;

                channel_AB_re = (no_change) ? data_in_re_AntennaB : ~data_in_re_AntennaB+1;
                channel_AB_im = (no_change) ? data_in_im_AntennaB : ~data_in_im_AntennaB+1;

            end
            2'b01: begin
                channel_BA_re = (no_change) ? data_in_re_AntennaA : ~data_in_re_AntennaA+1 ;
                channel_BA_im = (no_change) ? data_in_im_AntennaA : ~data_in_im_AntennaA+1 ;

                channel_BB_re = (no_change) ? data_in_re_AntennaB : ~data_in_re_AntennaB+1 ;
                channel_BB_im = (no_change) ? data_in_im_AntennaB : ~data_in_im_AntennaB+1 ;
            end
            2'b10: begin

                channel_BA_re = (no_change) ? data_in_re_AntennaA : ~data_in_re_AntennaA+1 ;
                channel_BA_im = (no_change) ? data_in_im_AntennaA : ~data_in_im_AntennaA+1 ;

                channel_BB_re = (no_change) ? data_in_re_AntennaB : ~data_in_re_AntennaB+1 ;
                channel_BB_im = (no_change) ? data_in_im_AntennaB : ~data_in_im_AntennaB+1 ;
            end
            2'b11: begin
                channel_AA_re = (no_change) ? data_in_re_AntennaA : ~data_in_re_AntennaA+1 ;
                channel_AA_im = (no_change) ? data_in_im_AntennaA : ~data_in_im_AntennaA+1 ;

                channel_AB_re = (no_change) ? data_in_re_AntennaB : ~data_in_re_AntennaB+1 ;
                channel_AB_im = (no_change) ? data_in_im_AntennaB : ~data_in_im_AntennaB+1 ;
            end
        endcase
    end
end
wire channel_loading = (channel_est_state == CHANNEL_ESTIMATE_LOADING_FIRST ||
                        channel_est_state == CHANNEL_ESTIMATE_LOADING_SECOND);

wire write_en_even = (first_est) ? mem_addr[0] & channel_loading 
                                 : ~mem_addr[0] & channel_loading ;

wire write_en_odd = (first_est) ? ~mem_addr[0] & channel_loading 
                                 : mem_addr[0] & channel_loading;


// -------------------- Channel Memory --------------------//

// AA
channel_mem #(
    .FIFO_LENGTH(64),.TOTAL_BIT(TOTAL_BIT),.ADDR_BIT(CHANNEL_CNT_BIT)
) channel_mem_AA (
    .clk(clk),
    
    .write_en(write_en_even),
    .write_addr(mem_addr),
    .data_in_re(channel_AA_re),.data_in_im(channel_AA_im),

    .read_addr(channel_est_cnt),
    .data_out_re(channel_out_AA_re),.data_out_im(channel_out_AA_im)
);
// AB
channel_mem #(
    .FIFO_LENGTH(64),.TOTAL_BIT(TOTAL_BIT),.ADDR_BIT(CHANNEL_CNT_BIT)
) channel_mem_AB (
    .clk(clk),
    
    .write_en(write_en_even),
    .write_addr(mem_addr),
    .data_in_re(channel_AB_re),.data_in_im(channel_AB_im),

    .read_addr(channel_est_cnt),
    .data_out_re(channel_out_AB_re),.data_out_im(channel_out_AB_im)
);
// BA
channel_mem #(
    .FIFO_LENGTH(64),.TOTAL_BIT(TOTAL_BIT),.ADDR_BIT(CHANNEL_CNT_BIT)
) channel_mem_BA (
    .clk(clk),
    
    .write_en(write_en_odd),
    .write_addr(mem_addr),
    .data_in_re(channel_BA_re),.data_in_im(channel_BA_im),

    .read_addr(channel_est_cnt),
    .data_out_re(channel_out_BA_re),.data_out_im(channel_out_BA_im)
);
//BB
channel_mem #(
    .FIFO_LENGTH(64),
    .TOTAL_BIT(TOTAL_BIT),
    .ADDR_BIT(CHANNEL_CNT_BIT)
) channel_mem_BB (
    .clk(clk),
    
    .write_en(write_en_odd),
    .write_addr(mem_addr),
    .data_in_re(channel_BB_re),.data_in_im(channel_BB_im),

    .read_addr(channel_est_cnt),
    .data_out_re(channel_out_BB_re),.data_out_im(channel_out_BB_im)
);

endmodule