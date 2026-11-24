module ping_pong_buffer #(
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT  = 8
) (
    input clk,
    input rst_n,
    
    // Top Level Input (Natural Order)
    input MIMO_detection_valid,
    input MIMO_detection_ready,
    input signed [TOTAL_BIT-1:0] RX_estimated_re,
    input signed [TOTAL_BIT-1:0] RX_estimated_im,

    // Top Level Output (Natural Order) 
    output reg serial_out_valid,
    output signed [TOTAL_BIT-1:0] serial_out_re,
    output signed [TOTAL_BIT-1:0] serial_out_im
);
localparam ADDR_BIT = 6;
localparam PP_BUTTER_STATE_BIT = 3;
localparam FFT_LENGTH = 64;

localparam PP_BUFFER_IDLE = 3'd0;
localparam PP_BUFFER_LOAD = 3'd1;
localparam PP_BUFFER_WAIT1 = 3'd2;
localparam PP_BUFFER_MODE1 = 3'd3;
localparam PP_BUFFER_WAIT2 = 3'd4;
localparam PP_BUFFER_MODE2 = 3'd5;


reg [PP_BUTTER_STATE_BIT-1:0] pp_buffer_state, pp_buffer_state_n;
reg [ADDR_BIT-1:0] pp_buffer_cnt, pp_buffer_cnt_n;

reg read_write_order;
reg [ADDR_BIT-1:0] mem_addr;

//==================== FSM ==========================//
always @(*) begin
    pp_buffer_state_n = pp_buffer_state;
    pp_buffer_cnt_n = pp_buffer_cnt;
    read_write_order = 0;
    serial_out_valid = 0;

    case (pp_buffer_state)
        PP_BUFFER_IDLE: begin
            pp_buffer_cnt_n = 0;
            if (MIMO_detection_ready) begin
                pp_buffer_state_n = PP_BUFFER_LOAD;
            end
        end
        PP_BUFFER_LOAD:begin
            pp_buffer_cnt_n = pp_buffer_cnt + 1;
            read_write_order = 0;
            if (pp_buffer_cnt == FFT_LENGTH-1) begin
                pp_buffer_state_n = PP_BUFFER_WAIT1;
            end
        end
        PP_BUFFER_WAIT1: begin
            pp_buffer_cnt_n = 0;
            if (MIMO_detection_ready) begin
                pp_buffer_state_n = PP_BUFFER_MODE1;
            end
        end
        PP_BUFFER_MODE1: begin
            pp_buffer_cnt_n = pp_buffer_cnt + 1;
            read_write_order = 1;
            serial_out_valid = 1;
            if (pp_buffer_cnt == FFT_LENGTH-1) begin
                pp_buffer_state_n = PP_BUFFER_WAIT2;
            end
        end
        PP_BUFFER_WAIT2: begin
            pp_buffer_cnt_n = 0;
            if (MIMO_detection_ready) begin
                pp_buffer_state_n = PP_BUFFER_MODE2;
            end
        end
        PP_BUFFER_MODE2: begin
            pp_buffer_cnt_n = pp_buffer_cnt + 1;
            read_write_order = 0;
            serial_out_valid = 1;
            if (pp_buffer_cnt == FFT_LENGTH-1) begin
                pp_buffer_state_n = PP_BUFFER_WAIT1;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (~rst_n) begin
        pp_buffer_state <= PP_BUFFER_IDLE;
        pp_buffer_cnt <= 0;
    end
    else begin
        pp_buffer_state <= pp_buffer_state_n;
        pp_buffer_cnt <= pp_buffer_cnt_n;
    end
end

//==================== Bits Reverse =========================//
integer i;
always @(*) begin
    for ( i=0 ; i< ADDR_BIT; i=i+1 ) begin
        mem_addr[i] = pp_buffer_cnt[(ADDR_BIT-1)-i];
    end
end

//==================== Chose Output ======================//
wire [TOTAL_BIT-1:0] read_write_out_re, read_write_out_im;
wire [TOTAL_BIT-1:0] write_read_out_re, write_read_out_im;

assign output_stage = (pp_buffer_state == PP_BUFFER_MODE1 || pp_buffer_state == PP_BUFFER_MODE2);

wire [TOTAL_BIT-1:0] output_re = (read_write_order) ? write_read_out_re : read_write_out_re;
wire [TOTAL_BIT-1:0] output_im = (read_write_order) ? write_read_out_im : read_write_out_im;

assign serial_out_re = (output_stage) ? output_re : 0;
assign serial_out_im = (output_stage) ? output_im : 0;


//==================== Data ROMs =========================//
channel_mem #(
    .FIFO_LENGTH(64),.TOTAL_BIT(TOTAL_BIT),.ADDR_BIT(ADDR_BIT)
) Read_write_buffer (
    .clk(clk),
    
    .write_en(read_write_order & MIMO_detection_valid),
    .write_addr(mem_addr),
    .data_in_re(RX_estimated_re),.data_in_im(RX_estimated_im),

    .read_addr(pp_buffer_cnt),
    .data_out_re(read_write_out_re),.data_out_im(read_write_out_im)
);

channel_mem #(
    .FIFO_LENGTH(64),.TOTAL_BIT(TOTAL_BIT),.ADDR_BIT(ADDR_BIT)
) Write_read_buffer (
    .clk(clk),
    
    .write_en(~read_write_order & MIMO_detection_valid),
    .write_addr(mem_addr),
    .data_in_re(RX_estimated_re),.data_in_im(RX_estimated_im),

    .read_addr(pp_buffer_cnt),
    .data_out_re(write_read_out_re),.data_out_im(write_read_out_im)
);
endmodule