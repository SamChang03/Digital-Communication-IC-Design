module OFDM_top
#(
    parameter  TOTAL_BITS = 20,
    parameter  FRACTION_BITS = 8
)
(
    input clk,         // clock 
    input srst_n,      // synchronous reset (active low)
    input enable_OFDM,      
    input enable_fft,      
    input signed [2*TOTAL_BITS-1:0] data_in,	
    
    output reg signed [1:0] data_out,
    output syn_valid,      
    output reg OFDM_valid      
);

wire signed [TOTAL_BITS-1:0] twiddle_factors [32 - 1 : 0][1:0];
reg code_valid_next; 
reg signed [1:0] data_out_next;
reg signed [TOTAL_BITS-1:0] symbol [1:0];
reg signed [TOTAL_BITS-1:0] symbol_next [1:0];
reg [6:0] cnt_load, cnt_load_next;

reg [6:0] cnt, cnt_next;
reg [2:0]state, ns;
localparam  OFDM_IDLE = 3'd0, OFDM_LOAD = 3'd1, OFDM_CAL = 3'd2, OFDM_DECODE = 3'd3 , OFDM_DONE = 3'd4, OFDM_SYNC = 3'd5;
integer  i, j;
reg signed [TOTAL_BITS-1:0] recent_symbol[1:0];
reg signed [TOTAL_BITS-1:0] real_out, img_out;
reg signed [TOTAL_BITS-1:0] out_sym [64 - 1 : 0] [1:0];
reg signed [TOTAL_BITS-1:0] out_sym_next [64 - 1 : 0] [1:0];

/***layer 1***/
reg signed [30:0] x1 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] q_x1 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] x1_out [32-1:0][1:0];
reg signed [TOTAL_BITS-1:0] x1_out_next [32-1:0][1:0];
reg [7:0] cnt_s1, cnt_s1_next;
reg [6:0] s1_flag, s1_flag_next;
reg signed [TOTAL_BITS-1:0] twiddle1_0 ;
reg signed [TOTAL_BITS-1:0] twiddle1_1 ;
reg select1;
reg signed [TOTAL_BITS-1:0] in1_high1;
reg signed [TOTAL_BITS-1:0] in1_high0;
wire signed [2*TOTAL_BITS-1:0] x1_in;

/***layer 2***/
reg signed [30:0] x2 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] q_x2 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] x2_out [16-1:0][1:0];
reg signed [TOTAL_BITS-1:0] x2_out_next [16-1:0][1:0];
reg [6:0] cnt_s2, cnt_s2_next;
reg [6:0] s2_flag, s2_flag_next;

reg signed [TOTAL_BITS-1:0] twiddle2_0 ;
reg signed [TOTAL_BITS-1:0] twiddle2_1 ;
reg select2;
reg signed [TOTAL_BITS-1:0] in2_high1;
reg signed [TOTAL_BITS-1:0] in2_high0;
wire signed [2*TOTAL_BITS-1:0] x2_in;
wire signed [2*TOTAL_BITS-1:0] x2_sym_in;
reg signed [2*TOTAL_BITS-1:0] x2_sym_in_reg;
/***layer 3***/
reg signed [30:0] x3 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] q_x3 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] x3_out [8-1:0][1:0];
reg signed [TOTAL_BITS-1:0] x3_out_next [8-1:0][1:0];
reg [6:0] cnt_s3, cnt_s3_next;
reg [6:0] s3_flag, s3_flag_next;

reg signed [TOTAL_BITS-1:0] twiddle3_0 ;
reg signed [TOTAL_BITS-1:0] twiddle3_1 ;
reg select3;
reg signed [TOTAL_BITS-1:0] in3_high1;
reg signed [TOTAL_BITS-1:0] in3_high0;
wire signed [2*TOTAL_BITS-1:0] x3_in;
wire signed [2*TOTAL_BITS-1:0] x3_sym_in;
reg signed [2*TOTAL_BITS-1:0] x3_sym_in_reg;
/***layer 4***/
reg signed [30:0] x4 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] q_x4 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] x4_out [4-1:0][1:0];
reg signed [TOTAL_BITS-1:0] x4_out_next [4-1:0][1:0];
reg [6:0] cnt_s4, cnt_s4_next;
reg [6:0] s4_flag, s4_flag_next;

reg signed [TOTAL_BITS-1:0] twiddle4_0 ;
reg signed [TOTAL_BITS-1:0] twiddle4_1 ;
reg select4;
reg signed [TOTAL_BITS-1:0] in4_high1;
reg signed [TOTAL_BITS-1:0] in4_high0;
wire signed [2*TOTAL_BITS-1:0] x4_in;
wire signed [2*TOTAL_BITS-1:0] x4_sym_in;
reg signed [2*TOTAL_BITS-1:0] x4_sym_in_reg;
/***layer 5***/
reg signed [30:0] x5 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] q_x5 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] x5_out [2-1:0][1:0];
reg signed [TOTAL_BITS-1:0] x5_out_next [2-1:0][1:0];
reg [6:0] cnt_s5, cnt_s5_next;
reg [6:0] s5_flag, s5_flag_next;

reg signed [TOTAL_BITS-1:0] twiddle5_0 ;
reg signed [TOTAL_BITS-1:0] twiddle5_1 ;
reg select5;
reg signed [TOTAL_BITS-1:0] in5_high1;
reg signed [TOTAL_BITS-1:0] in5_high0;
wire signed [2*TOTAL_BITS-1:0] x5_in;
wire signed [2*TOTAL_BITS-1:0] x5_sym_in;
reg signed [2*TOTAL_BITS-1:0] x5_sym_in_reg;
/***layer 6***/
reg signed [30:0] x6 [1:0][1:0];
reg signed [TOTAL_BITS-1:0] x6_out [1:0];
reg signed [TOTAL_BITS-1:0] x6_out_next [1:0];
reg [6:0] cnt_s6, cnt_s6_next;
reg [6:0] s6_flag, s6_flag_next;
reg signed [TOTAL_BITS-1:0] twiddle6_0 ;
reg signed [TOTAL_BITS-1:0] twiddle6_1 ;
reg select6;
reg signed [TOTAL_BITS-1:0] in6_high1;
reg signed [TOTAL_BITS-1:0] in6_high0;
wire signed [2*TOTAL_BITS-1:0] x6_in;
wire signed [2*TOTAL_BITS-1:0] x6_sym_in;
reg signed [2*TOTAL_BITS-1:0] x6_sym_in_reg;
wire signed [2*TOTAL_BITS-1:0] x7_in;

reg s6_start_next, s6_start;
reg s5_start_next, s5_start;
reg s4_start_next, s4_start;
reg s3_start_next, s3_start;
reg s2_start_next, s2_start;
reg s1_start_next, s1_start;

reg [5:0] m1, p1, n2, n3, n4, n5, n6;
reg [5:0] m2;
reg [5:0] p2;

reg [5:0] m3;
reg [5:0] p3;
reg [5:0] m4;
reg [5:0] p4;
reg [5:0] m5;
reg [5:0] p5;
reg [5:0] m6;
reg [5:0] p6;
wire [5:0] cnt_reverse;
wire [5:0] out_boundary;
reg [5:0] boundary_reg, boundary_next;

synchronization u_synchronization(
.clk(clk), 
.srst_n(srst_n), 
.enable(enable_OFDM),  
.data_in(data_in), 
.out_boundary(out_boundary), 
.code_valid(syn_valid)
);

always @(posedge clk) begin
    if(~srst_n)begin
        OFDM_valid <= 0;
        cnt <= 0;
        cnt_s1 <= 0;
        cnt_load <= 0;
        state <= 0;
        data_out <= 0;
        s6_start <= 0;
        s5_start <= 0;
        s4_start <= 0;
        s3_start <= 0;
        s2_start <= 0;
        s1_start <= 0;
        
        x2_sym_in_reg <= 0;
        x3_sym_in_reg <= 0;
        x4_sym_in_reg <= 0;
        x5_sym_in_reg <= 0;
        x6_sym_in_reg <= 0;
        boundary_reg <= 0;
        for(j = 0; j < 2; j = j + 1) begin
            for(i = 0; i < 32; i = i + 1) begin
                x1_out[i][j] <= 0 ;
            end     
        end
        s2_flag <= 0;
        cnt_s2 <= 0;
        for(j = 0; j < 2; j = j + 1) begin
            for(i = 0; i < 16; i = i + 1) begin
                x2_out[i][j] <= 0 ;
            end     
        end
        s3_flag <= 0;
        cnt_s3 <= 0;
        for(j = 0; j < 2; j = j + 1) begin
            for(i = 0; i < 8; i = i + 1) begin
                x3_out[i][j] <= 0 ;
            end     
        end
        s4_flag <= 0;
        cnt_s4 <= 0;
        for(j = 0; j < 2; j = j + 1) begin
            for(i = 0; i < 4; i = i + 1) begin
                x4_out[i][j] <= 0 ;
            end     
        end
        s5_flag <= 0;
        cnt_s5 <= 0;
        for(j = 0; j < 2; j = j + 1) begin
            for(i = 0; i < 2; i = i + 1) begin
                x5_out[i][j] <= 0 ;
            end     
        end
        s6_flag <= 0;
        cnt_s6 <= 0;
        for(j = 0; j < 2; j = j + 1) begin
                x6_out[j] <= 0 ;  
        end
        for(j = 0; j < 2; j = j + 1) begin
                symbol[j] <= 0 ;    
        end
        for(j = 0; j < 64; j = j + 1) begin
            for(i = 0; i < 2; i = i + 1) begin
                out_sym[j][i] <= 0 ;    
            end  
        end
    end
    else begin
        OFDM_valid <= code_valid_next;
        cnt_s1 <= cnt_s1_next;
        cnt <= cnt_next;
        cnt_load <= cnt_load_next;
        state <= ns;
        data_out <= data_out_next;
        s6_start <= s6_start_next;
        s5_start <= s5_start_next;
        s4_start <= s4_start_next;
        s3_start <= s3_start_next;
        s2_start <= s2_start_next;
        s1_start <= s1_start_next;
 
        x2_sym_in_reg <= x2_sym_in;
        x3_sym_in_reg <= x3_sym_in;
        x4_sym_in_reg <= x4_sym_in;
        x5_sym_in_reg <= x5_sym_in;
        x6_sym_in_reg <= x6_sym_in;
        boundary_reg <= boundary_next;
        for(j = 0; j < 2; j = j + 1) begin
            for(i = 0; i < 32; i = i + 1) begin
                x1_out[i][j] <= x1_out_next[i][j];
            end     
        end

        s2_flag <= s2_flag_next;
        cnt_s2 <= cnt_s2_next;
        for(j = 0; j < 2; j = j + 1) begin
            for(i = 0; i < 16; i = i + 1) begin
                x2_out[i][j] <= x2_out_next[i][j];
            end     
        end

        s3_flag <= s3_flag_next;
        cnt_s3 <= cnt_s3_next;
        for (j = 0; j < 2; j = j + 1) begin
            for (i = 0; i < 8; i = i + 1) begin
                x3_out[i][j] <= x3_out_next[i][j];
            end     
        end
        
        s4_flag <= s4_flag_next;
        cnt_s4 <= cnt_s4_next;
        for (j = 0; j < 2; j = j + 1) begin
            for (i = 0; i < 4; i = i + 1) begin
                x4_out[i][j] <= x4_out_next[i][j];
            end     
        end
        
        s5_flag <= s5_flag_next;
        cnt_s5 <= cnt_s5_next;
        for (j = 0; j < 2; j = j + 1) begin
            for (i = 0; i < 2; i = i + 1) begin
                x5_out[i][j] <= x5_out_next[i][j];
            end     
        end
        
        s6_flag <= s6_flag_next;
        cnt_s6 <= cnt_s6_next;
        for (j = 0; j < 2; j = j + 1) begin
                x6_out[j] <= x6_out_next[j];   
        end
    
        for(j = 0; j < 2; j = j + 1) begin
                symbol[j] <= symbol_next[j] ;  
        end
        for(j = 0; j < 64; j = j + 1) begin
            for(i = 0; i < 2; i = i + 1) begin
                out_sym[j][i] <= out_sym_next[j][i] ;    
            end      
        end
    end
end

always @(*) begin
    if(syn_valid)
        boundary_next = out_boundary;
    else
        boundary_next = boundary_reg;       
end
always @(*) begin
    real_out = out_sym[cnt_reverse][1];
    img_out = out_sym[cnt_reverse][0];
    data_out_next[1] = (real_out >= 0);
    data_out_next[0] = (img_out >= 0);
end


always @(*) begin
    ns = OFDM_IDLE;
    case (state)
        OFDM_IDLE : ns = enable_fft ? OFDM_SYNC: state;
        OFDM_SYNC : ns = cnt_load_next == boundary_reg ? OFDM_CAL :state;
        OFDM_CAL : ns = s6_flag == 31 && s6_flag_next == 0 ? OFDM_DECODE:state; 
        OFDM_DECODE : ns = cnt == 63 ? OFDM_DONE: state;
        OFDM_DONE : ns =  OFDM_IDLE; 
    endcase
end



always @(*) begin
    symbol_next[0] = enable_fft ? data_in[TOTAL_BITS-1:0] : 0;
    symbol_next[1] = enable_fft ? data_in[2*TOTAL_BITS-1:TOTAL_BITS] : 0;
end



always @(*) begin
    if(ns != state)
        cnt_next = 0;
    else
        cnt_next = cnt + 1;
end

always @(*) begin
    if(ns != state && ns == OFDM_SYNC)
        cnt_load_next = 0;
    else if(cnt_load == 63)
        cnt_load_next = 64;
    else if(cnt_load < 64)
        cnt_load_next = cnt_load + 1;
    else
        cnt_load_next = cnt_load;
end


assign cnt_reverse[0] = cnt[5];
assign cnt_reverse[1] = cnt[4];
assign cnt_reverse[2] = cnt[3];
assign cnt_reverse[3] = cnt[2];
assign cnt_reverse[4] = cnt[1];
assign cnt_reverse[5] = cnt[0];

always @(*) begin
    if(state == OFDM_DECODE) begin
        code_valid_next = 1;
       // data_out_next = {x6_out[cnt_reverse][1], x6_out[cnt_reverse][0]};
    end
    else begin
        code_valid_next = 0;
     //   data_out_next = 0;
    end
end



////////////////////////////////////////////////////////////////////////////////////first layer////////////////////////////////////////////////////
always @(*) begin
    for(i = 0; i < 31; i = i + 1) begin
        x1_out_next[i][0] = x1_out[i + 1][0] ;
        x1_out_next[i][1] = x1_out[i + 1][1] ;    
    end
    x1_out_next[31][1] = x1_in[2*TOTAL_BITS-1:TOTAL_BITS];
    x1_out_next[31][0] = x1_in[TOTAL_BITS-1:0];
end

always @(*) begin
    if(s1_start == 0 && ns == OFDM_CAL)
        s1_start_next = 1;
    else
        s1_start_next = s1_start;
end

always @(*) begin
    if(cnt_s1 == 64)
        cnt_s1_next = 1;
    else if(s1_start)
        cnt_s1_next = cnt_s1 + 1;
    else
        cnt_s1_next = cnt_s1;
end

always @(*) begin
    p1 = 0;
    twiddle1_1 = twiddle_factors[p1][1];
    twiddle1_0 = twiddle_factors[p1][0];
    select1 = cnt_s1_next > 32 ? 0: 1;
end

BF u_BF1 
(
.select(select1),      
.twiddle_factors1(twiddle1_1),
.twiddle_factors0(twiddle1_0),
.in_low0(x1_out[0][0]),	// 0
.in_low1(x1_out[0][1]),	// 0
.in_high0(symbol[0]),	// 32
.in_high1(symbol[1]),	// 32
.code_high(x2_sym_in),
.code_low(x1_in)    
);
////////////////////////////////////////////////////////////////////////////////////first layer////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////////Second layer////////////////////////////////////////////////////
always @(*) begin
    for(i = 0; i < 15; i = i + 1) begin
        x2_out_next[i][0] = x2_out[i + 1][0] ;
        x2_out_next[i][1] = x2_out[i + 1][1] ;    
    end
        x2_out_next[15][1] = x2_in[2*TOTAL_BITS-1:TOTAL_BITS] ;
        x2_out_next[15][0] = x2_in[TOTAL_BITS-1:0] ;     
end

always @(*) begin
    if(s2_start == 0 && cnt_s1 == 32)
        s2_start_next = 1;
    else
        s2_start_next = s2_start;
end

always @(*) begin
    if(cnt_s2 == 32)
        cnt_s2_next = 1;
    else if(s2_start)
        cnt_s2_next = cnt_s2 + 1;
    else
        cnt_s2_next = cnt_s2;
end

always @(*) begin
    if(cnt_s2 == 32 && s2_flag != (2-1))
        s2_flag_next = s2_flag + 1;
    else if(cnt_s2 == 32 && s2_flag == (2-1))
        s2_flag_next = 0;       
    else
        s2_flag_next = s2_flag;
end

always @(*) begin
    m2 = 2 * s2_flag;
    p2[5] = m2[0];
    p2[4] = m2[1];
    p2[3] = m2[2];
    p2[2] = m2[3];
    p2[1] = m2[4];
    p2[0] = m2[5];
    n2 = 16;
    twiddle2_1 = twiddle_factors[p2][1];
    twiddle2_0 = twiddle_factors[p2][0];
    select2 = cnt_s2_next > 16 ? 0: 1;
    in2_high1 = x2_sym_in_reg[2*TOTAL_BITS-1:TOTAL_BITS];
    in2_high0 = x2_sym_in_reg[TOTAL_BITS-1:0];
end

BF u_BF2 
(
.select(select2),      
.twiddle_factors1(twiddle2_1),
.twiddle_factors0(twiddle2_0),
.in_low0(x2_out[0][0]),	// 0
.in_low1(x2_out[0][1]),	// 0
.in_high0(in2_high0),	// 32
.in_high1(in2_high1),	// 32
.code_high(x3_sym_in),
.code_low(x2_in)    
);
////////////////////////////////////////////////////////////////////////////////////Second layer////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////3 layer////////////////////////////////////////////////////
always @(*) begin
    for(i = 0; i < 7; i = i + 1) begin
        x3_out_next[i][0] = x3_out[i+1][0] ;
        x3_out_next[i][1] = x3_out[i+1][1] ;    
    end
        x3_out_next[7][1] = x3_in[2*TOTAL_BITS-1:TOTAL_BITS] ;
        x3_out_next[7][0] = x3_in[TOTAL_BITS-1:0] ;  
  
end

always @(*) begin
    if(s3_start == 0 && cnt_s2 == 16)
        s3_start_next = 1;
    else
        s3_start_next = s3_start;
end

always @(*) begin
    if(cnt_s3 == 16)
        cnt_s3_next = 1;
    else if(s3_start)
        cnt_s3_next = cnt_s3 + 1;
    else
        cnt_s3_next = cnt_s3;
end

always @(*) begin
    if(cnt_s3 == 16 && s3_flag != (4-1))
        s3_flag_next = s3_flag + 1;
    else if(cnt_s3 == 16 && s3_flag == (4-1))
        s3_flag_next = 0;
    else
        s3_flag_next = s3_flag;
end

always @(*) begin
    m3 = 2 * s3_flag;
    p3[5] = m3[0];
    p3[4] = m3[1];
    p3[3] = m3[2];
    p3[2] = m3[3];
    p3[1] = m3[4];
    p3[0] = m3[5];
    n3 = 8;
    twiddle3_1 = twiddle_factors[p3][1];
    twiddle3_0 = twiddle_factors[p3][0];
    select3 = cnt_s3_next > 8 ? 0: 1;
    in3_high1 = x3_sym_in_reg[2*TOTAL_BITS-1:TOTAL_BITS];
    in3_high0 = x3_sym_in_reg[TOTAL_BITS-1:0];
end

BF u_BF3 
(
.select(select3),      
.twiddle_factors1(twiddle3_1),
.twiddle_factors0(twiddle3_0),
.in_low0(x3_out[0][0]),	// 0
.in_low1(x3_out[0][1]),	// 0
.in_high0(in3_high0),	// 32
.in_high1(in3_high1),	// 32
.code_high(x4_sym_in),
.code_low(x3_in)    
);

////////////////////////////////////////////////////////////////////////////////////3 layer////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////4 layer////////////////////////////////////////////////////
always @(*) begin
    for(i = 0; i < 3; i = i + 1) begin
        x4_out_next[i][0] = x4_out[i+1][0] ;
        x4_out_next[i][1] = x4_out[i+1][1] ;    
    end
    x4_out_next[3][1] = x4_in[2*TOTAL_BITS-1:TOTAL_BITS] ;
    x4_out_next[3][0] = x4_in[TOTAL_BITS-1:0] ;        
end

always @(*) begin
    if(s4_start == 0 && cnt_s3 == 8)
        s4_start_next = 1;
    else
        s4_start_next = s4_start;
end

always @(*) begin
    if(cnt_s4 == 8)
        cnt_s4_next = 1;
    else if(s4_start)
        cnt_s4_next = cnt_s4 + 1;
    else
        cnt_s4_next = cnt_s4;
end

always @(*) begin
    if(cnt_s4 == 8 && s4_flag != (8-1))
        s4_flag_next = s4_flag + 1;
    else if(cnt_s4 == 8 && s4_flag == (8-1))
        s4_flag_next = 0;
    else
        s4_flag_next = s4_flag;
end

always @(*) begin
    m4 = 2 * s4_flag;
    p4[5] = m4[0];
    p4[4] = m4[1];
    p4[3] = m4[2];
    p4[2] = m4[3];
    p4[1] = m4[4];
    p4[0] = m4[5];
    n4 = 4;
    twiddle4_1 = twiddle_factors[p4][1];
    twiddle4_0 = twiddle_factors[p4][0];
    select4 = cnt_s4_next > 4 ? 0: 1;
    in4_high1 = x4_sym_in_reg[2*TOTAL_BITS-1:TOTAL_BITS];
    in4_high0 = x4_sym_in_reg[TOTAL_BITS-1:0];
end

BF u_BF4 
(
.select(select4),      
.twiddle_factors1(twiddle4_1),
.twiddle_factors0(twiddle4_0),
.in_low0(x4_out[0][0]),	// 0
.in_low1(x4_out[0][1]),	// 0
.in_high0(in4_high0),	// 32
.in_high1(in4_high1),	// 32
.code_high(x5_sym_in),
.code_low(x4_in)    
);

////////////////////////////////////////////////////////////////////////////////////4 layer////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////5 layer////////////////////////////////////////////////////
always @(*) begin
    for(i = 0; i < 1; i = i + 1) begin
        x5_out_next[i][0] = x5_out[i + 1][0] ;
        x5_out_next[i][1] = x5_out[i + 1][1] ;    
    end
        x5_out_next[1][1] = x5_in[2*TOTAL_BITS-1:TOTAL_BITS] ;
        x5_out_next[1][0] = x5_in[TOTAL_BITS-1:0] ;    
end


always @(*) begin
    if(s5_start == 0 && cnt_s4 == 4)
        s5_start_next = 1;
    else
        s5_start_next = s5_start;
end

always @(*) begin
    if(cnt_s5 == 4)
        cnt_s5_next = 1;
    else if(s5_start)
        cnt_s5_next = cnt_s5 + 1;
    else
        cnt_s5_next = cnt_s5;
end

always @(*) begin
    if(cnt_s5 == 4 && s5_flag != (16-1))
        s5_flag_next = s5_flag + 1;
    else if(cnt_s5 == 4 && s5_flag == (16-1))
        s5_flag_next = 0;
    else
        s5_flag_next = s5_flag;
end

always @(*) begin
    m5 = 2 * s5_flag;
    p5[5] = m5[0];
    p5[4] = m5[1];
    p5[3] = m5[2];
    p5[2] = m5[3];
    p5[1] = m5[4];
    p5[0] = m5[5];
    n5 = 2;
    twiddle5_1 = twiddle_factors[p5][1];
    twiddle5_0 = twiddle_factors[p5][0];
    select5 = cnt_s5_next > 2 ? 0: 1;
    in5_high1 = x5_sym_in_reg[2*TOTAL_BITS-1:TOTAL_BITS];
    in5_high0 = x5_sym_in_reg[TOTAL_BITS-1:0];
end
BF u_BF5 
(
.select(select5),      
.twiddle_factors1(twiddle5_1),
.twiddle_factors0(twiddle5_0),
.in_low0(x5_out[0][0]),	// 0
.in_low1(x5_out[0][1]),	// 0
.in_high0(in5_high0),	// 32
.in_high1(in5_high1),	// 32
.code_high(x6_sym_in),
.code_low(x5_in)    
);
////////////////////////////////////////////////////////////////////////////////////5 layer////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////6 layer////////////////////////////////////////////////////
always @(*) begin
        x6_out_next[1] = x6_in[2*TOTAL_BITS-1:TOTAL_BITS] ;
        x6_out_next[0] = x6_in[TOTAL_BITS-1:0] ;    
end

always @(*) begin

    if(s6_start == 0 && cnt_s5 == 2)
        s6_start_next = 1;
    else
        s6_start_next = s6_start;

    if(cnt_s6 == 2)
        cnt_s6_next = 1;
    else if(s6_start)
        cnt_s6_next = cnt_s6 + 1;
    else
        cnt_s6_next = cnt_s6;

    if(cnt_s6 == 2 && s6_flag != (32-1))
        s6_flag_next = s6_flag + 1;
    else if(cnt_s6 == 2 && s6_flag == (32-1))
        s6_flag_next = 0;
    else
        s6_flag_next = s6_flag;
end


always @(*) begin
    m6 = 2 * s6_flag;
    p6[5] = m6[0];
    p6[4] = m6[1];
    p6[3] = m6[2];
    p6[2] = m6[3];
    p6[1] = m6[4];
    p6[0] = m6[5];
    n6 = 1;
    twiddle6_1 = twiddle_factors[p6][1];
    twiddle6_0 = twiddle_factors[p6][0];
    select6 = cnt_s6_next > 1 ? 0: 1;
    in6_high1 = x6_sym_in_reg[2*TOTAL_BITS-1:TOTAL_BITS];
    in6_high0 = x6_sym_in_reg[TOTAL_BITS-1:0];
end
BF u_BF6
(
.select(select6),      
.twiddle_factors1(twiddle6_1),
.twiddle_factors0(twiddle6_0),
.in_low0(x6_out[0]),	// 0
.in_low1(x6_out[1]),	// 0
.in_high0(in6_high0),	// 32
.in_high1(in6_high1),	// 32
.code_high(x7_in),
.code_low(x6_in)    
);
////////////////////////////////////////////////////////////////////////////////////6 layer////////////////////////////////////////////////////

always @(*) begin
    if(state == OFDM_DECODE) begin
        for(i = 0; i < 2; i = i + 1) begin
            for(j = 0; j < 64; j = j + 1) begin
                out_sym_next[j][i] = out_sym[j][i] ;    
            end 
        end       
    end
    else begin
    for(i = 0; i < 2; i = i + 1) begin
        for(j = 0; j < 63; j = j + 1) begin
            out_sym_next[j][i] = out_sym[j+1][i] ;    
        end 
    end
    out_sym_next[63][0] = x7_in[TOTAL_BITS-1:0]; 
    out_sym_next[63][1] = x7_in[2*TOTAL_BITS-1:TOTAL_BITS]; 
        
    end
end

// LUT for twiddle_factors
assign twiddle_factors[0][1] = 1024;
assign twiddle_factors[0][0] = 0;
assign twiddle_factors[1][1] = 1019;
assign twiddle_factors[1][0] = -100;
assign twiddle_factors[2][1] = 1004;
assign twiddle_factors[2][0] = -199;
assign twiddle_factors[3][1] = 979;
assign twiddle_factors[3][0] = -297;
assign twiddle_factors[4][1] = 946;
assign twiddle_factors[4][0] = -391;
assign twiddle_factors[5][1] = 903;
assign twiddle_factors[5][0] = -482;
assign twiddle_factors[6][1] = 851;
assign twiddle_factors[6][0] = -568;
assign twiddle_factors[7][1] = 791;
assign twiddle_factors[7][0] = -649;
assign twiddle_factors[8][1] = 724;
assign twiddle_factors[8][0] = -724;
assign twiddle_factors[9][1] = 649;
assign twiddle_factors[9][0] = -791;
assign twiddle_factors[10][1] = 568;
assign twiddle_factors[10][0] = -851;
assign twiddle_factors[11][1] = 482;
assign twiddle_factors[11][0] = -903;
assign twiddle_factors[12][1] = 391;
assign twiddle_factors[12][0] = -946;
assign twiddle_factors[13][1] = 297;
assign twiddle_factors[13][0] = -979;
assign twiddle_factors[14][1] = 199;
assign twiddle_factors[14][0] = -1004;
assign twiddle_factors[15][1] = 100;
assign twiddle_factors[15][0] = -1019;
assign twiddle_factors[16][1] = 0;
assign twiddle_factors[16][0] = -1024;

assign twiddle_factors[17][1] = -100;
assign twiddle_factors[17][0] = -1019;
assign twiddle_factors[18][1] = -199;
assign twiddle_factors[18][0] = -1004;
assign twiddle_factors[19][1] = -297;
assign twiddle_factors[19][0] = -979;
assign twiddle_factors[20][1] = -391;
assign twiddle_factors[20][0] = -946;
assign twiddle_factors[21][1] = -482;
assign twiddle_factors[21][0] = -903;
assign twiddle_factors[22][1] = -568;
assign twiddle_factors[22][0] = -851;
assign twiddle_factors[23][1] = -649;
assign twiddle_factors[23][0] = -791;
assign twiddle_factors[24][1] = -724;
assign twiddle_factors[24][0] = -724;
assign twiddle_factors[25][1] = -791;
assign twiddle_factors[25][0] = -649;
assign twiddle_factors[26][1] = -851;
assign twiddle_factors[26][0] = -568;
assign twiddle_factors[27][1] = -903;
assign twiddle_factors[27][0] = -482;
assign twiddle_factors[28][1] = -946;
assign twiddle_factors[28][0] = -391;
assign twiddle_factors[29][1] = -979;
assign twiddle_factors[29][0] = -297;
assign twiddle_factors[30][1] = -1004;
assign twiddle_factors[30][0] = -199;
assign twiddle_factors[31][1] = -1019;
assign twiddle_factors[31][0] = -100;

endmodule