module synchronization
#(
    parameter  TOTAL_BITS = 20,
    parameter  FRACTION_BITS = 8
)
(
input clk,         // clock 
input srst_n,      // synchronous reset (active low)
input sync_enable,      

input signed [2*TOTAL_BITS-1:0] signal_in,	
output reg [6-1:0] out_boundary,
output reg sync_valid      
);

reg [6-1:0] out_boundary_next;  
reg sync_valid_next; 
reg signed [2*TOTAL_BITS-1:0] symbol [3*84-1:0];
reg signed [2*TOTAL_BITS-1:0] symbol_next [3*84-1:0];
reg signed [30:0] max_corr, max_corr_next;
reg [6-1:0] guard_length, guard_length_next;
reg [4:0] cnt_length, cnt_length_next;
reg [4:0] cnt_num, cnt_num_next;
reg [2:0]state, ns;
localparam  SYNC_IDLE = 3'd0, SYNC_LOAD = 3'd1, SYNC_CALC = 3'd2, SYNC_DONE = 3'd3;
integer  i, j;

reg signed [30:0] sum;
wire signed [30:0] sum_tmp;
reg signed [30:0] sum_next;
wire signed  [TOTAL_BITS - 1:0]  real1_0, real1_1, img1_0, img1_1;
wire signed  [TOTAL_BITS - 1:0]  real2_0, real2_1, img2_0, img2_1;
wire signed  [TOTAL_BITS - 1:0]  real3_0, real3_1, img3_0, img3_1;
always @(posedge clk) begin
    if(~srst_n)begin
        max_corr <= -2048;
        out_boundary <= 0;
        sync_valid <= 0;
        guard_length <= 0;
        cnt_length <= 0;
        cnt_num <= 0;
        sum <= 0;
        state <= 0;
        for(i = 0; i < 3*84; i = i + 1) begin
            symbol[i] <= 0;
        end
    end
    else begin
        max_corr <= max_corr_next;
        out_boundary <= out_boundary_next;
        sync_valid <= sync_valid_next;
        guard_length <= guard_length_next;
        cnt_length <= cnt_length_next;
        sum <= sum_next;
        cnt_num <= cnt_num_next;
        state <= ns;
        for(i = 0; i < 3*84; i = i + 1) begin
            symbol[i] <= symbol_next[i] ;
        end
    end
end

always @(*) begin
    ns = SYNC_IDLE;
    case (state)
        SYNC_IDLE : ns = sync_enable ? SYNC_LOAD: state;
        SYNC_LOAD : ns = !sync_enable ? SYNC_CALC: state; 
        SYNC_CALC : ns = cnt_length == 20 && cnt_num == cnt_length - 1 ? SYNC_DONE : state;
        SYNC_DONE : ns = SYNC_IDLE; 
    endcase
end

always @(*) begin
    if(ns == SYNC_LOAD ) begin
        for(i = 0; i < 3*84-1; i = i + 1) 
            symbol_next[i] = symbol[i+1] ;
        symbol_next[3*84-1] = signal_in;
    end
    else begin
        for(i = 0; i < 3*84; i = i + 1) 
            symbol_next[i] = symbol[i] ;    
    end
end

always @(*) begin
    if(ns == SYNC_CALC && state != ns)    // guard
        cnt_length_next = 1;
    else if(ns == SYNC_CALC && cnt_num == cnt_length - 1)
        cnt_length_next = cnt_length + 1;
    else
        cnt_length_next = cnt_length;
end

always @(*) begin
    if(ns == SYNC_CALC && state != ns || cnt_num == cnt_length - 1)  // tau
        cnt_num_next = 0;
    else if(ns == SYNC_CALC)
        cnt_num_next = cnt_num + 1;
    else
        cnt_num_next = 0;
end

// Complex Computation
assign real1_0 = symbol[63 + cnt_length - cnt_num][2*TOTAL_BITS-1:TOTAL_BITS];
assign img1_0 = symbol[63 + cnt_length - cnt_num - 64][TOTAL_BITS - 1:0];
assign real1_1 = symbol[63 + cnt_length - cnt_num - 64][2*TOTAL_BITS-1:TOTAL_BITS];
assign img1_1 = symbol[63 + cnt_length - cnt_num][TOTAL_BITS - 1:0];

assign real2_0 = symbol[(64 + cnt_length) * 2 - 1 - cnt_num][2*TOTAL_BITS-1:TOTAL_BITS];
assign img2_0 = symbol[(64 + cnt_length) * 2 - 1 - cnt_num - 64][TOTAL_BITS - 1:0];
assign real2_1 = symbol[(64 + cnt_length) * 2 - 1 - cnt_num - 64][2*TOTAL_BITS-1:TOTAL_BITS];
assign img2_1 = symbol[(64 + cnt_length) * 2 - 1 - cnt_num][TOTAL_BITS - 1:0];

assign real3_0 = symbol[(64 + cnt_length) * 3 - 1 - cnt_num][2*TOTAL_BITS-1:TOTAL_BITS];
assign img3_0 = symbol[(64 + cnt_length) * 3 - 1 - cnt_num - 64][TOTAL_BITS - 1:0];
assign real3_1 = symbol[(64 + cnt_length) * 3 - 1 - cnt_num - 64][2*TOTAL_BITS-1:TOTAL_BITS];
assign img3_1 = symbol[(64 + cnt_length) * 3 - 1 - cnt_num][TOTAL_BITS - 1:0];

assign sum_tmp = sum + ((real1_0 * real1_1 + img1_0 * img1_1) >>> FRACTION_BITS)
+ ((real2_0 * real2_1 + img2_0 * img2_1) >>> FRACTION_BITS)
+ ((real3_0 * real3_1 + img3_0 * img3_1) >>> FRACTION_BITS);

always @(*) begin
    if(state == SYNC_CALC && cnt_num == cnt_length - 1) begin
        sum_next = 0;
    end
    else if(state == SYNC_CALC)
        sum_next = sum_tmp;
    else
        sum_next = sum;
    end


always @(*) begin
    if(sum_tmp > max_corr && cnt_num == cnt_length - 1) begin
        max_corr_next = sum_tmp;
        guard_length_next = cnt_length;
    end
    else begin
        max_corr_next = max_corr;
        guard_length_next = guard_length;
    end
end

always @(*) begin
    if(state == SYNC_DONE) begin
        out_boundary_next = guard_length;
        sync_valid_next = 1;
    end
    else begin
        out_boundary_next = 0;
        sync_valid_next = 0;
    end
end
endmodule
