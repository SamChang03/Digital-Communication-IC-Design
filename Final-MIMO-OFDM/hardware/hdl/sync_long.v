module sync_long #
(
    parameter FIFO_LENGTH = 64,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8,
    parameter THRESHOLD_SCALE = 7000
)
(
    input clk,
    input rst_n,
    input enable,

    input [TOTAL_BIT-1:0] sample_in_re,
    input [TOTAL_BIT-1:0] sample_in_im,

    output long_preamble_detected
);

wire signed[TOTAL_BIT-1:0] lts_real [0:FIFO_LENGTH-1];
wire signed[TOTAL_BIT-1:0] lts_imag [0:FIFO_LENGTH-1];
wire signed[TOTAL_BIT-1:0] lts_imag_inv [0:FIFO_LENGTH-1];

wire signed [TOTAL_BIT-1:0] multi_real [0:FIFO_LENGTH-1];
wire signed [TOTAL_BIT-1:0] multi_imag [0:FIFO_LENGTH-1];

wire signed [TOTAL_BIT-1:0] sum_real [0:FIFO_LENGTH-1];
wire signed [TOTAL_BIT-1:0] sum_imag [0:FIFO_LENGTH-1];

reg signed [TOTAL_BIT-1:0] FF_real [1:FIFO_LENGTH];
reg signed [TOTAL_BIT-1:0] FF_imag [1:FIFO_LENGTH];


wire [TOTAL_BIT-1:0] cross_real, cross_imag, cross_norm;

//------------------------- Output -------------------------------//
assign cross_real = FF_real[FIFO_LENGTH];
assign cross_imag = FF_imag[FIFO_LENGTH];
assign long_preamble_detected = cross_norm > THRESHOLD_SCALE; 
//------------ Turn Complex to norm -------------//
complex_to_mag#(
    .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
) complex_to_mag (
    .i(cross_real),
    .q(cross_imag),
    
    .mag(cross_norm)  
);

//------------ TRANSEPOSE FIR -------------//
genvar i;
generate
    for ( i=0 ; i<FIFO_LENGTH ; i=i+1) begin: TRANSEPOSE_FIR
        // Multiplication
        assign lts_imag_inv[i] = ~lts_imag[i] +1; 

        complex_mult #(
            .TOTAL_BIT(TOTAL_BIT),.FRAC_BIT(FRAC_BIT)
        )
        complex_mult_inst 
        (
            .din_re(sample_in_re),
            .din_im(sample_in_im),
            .din_2_re(lts_real[i]),
            .din_2_im(lts_imag_inv[i]),

            .dout_re(multi_real[i]),
            .dout_im(multi_imag[i])
        );
        // Summation
        if (i==0) begin
            assign sum_real[0] = multi_real[0];
            assign sum_imag[0] = multi_imag[0];
        end
        else begin
            complex_add #(
                .TOTAL_BIT(TOTAL_BIT),
                .FRAC_BIT(FRAC_BIT)
            ) BF_add (
                .a_re(multi_real[i]), .a_im(multi_imag[i]),
                .b_re(FF_real[i]), .b_im(FF_imag[i]),

                .y_re(sum_real[i]), .y_im(sum_imag[i])
            );
        end
    end
endgenerate

//---------------------------D-FF--------------------------------//
integer j;
always @(posedge clk) begin
    if (~rst_n) begin
        for ( j=1 ; j<=FIFO_LENGTH ; j=j+1) begin
            FF_real[j] <= 0;
            FF_imag[j] <= 0;
        end
    end
    else if(enable) begin
        for (j = 1; j <= FIFO_LENGTH; j = j + 1) begin
            FF_real[j] <= sum_real[j-1]; 
            FF_imag[j] <= sum_imag[j-1];
        end
    end

end
//////////////// window LUT ////////////////

// LTS Real Part (from LTS_real.txt)
assign lts_real[0]  = 16'h030d;
assign lts_real[1]  = 16'hff6d;
assign lts_real[2]  = 16'h00b4;
assign lts_real[3]  = 16'hfe9a;
assign lts_real[4]  = 16'h0057;
assign lts_real[5]  = 16'h0015;
assign lts_real[6]  = 16'hff9c;
assign lts_real[7]  = 16'hff9b;
assign lts_real[8]  = 16'h0032;
assign lts_real[9]  = 16'hff8e;
assign lts_real[10] = 16'hffaa;
assign lts_real[11] = 16'hffd1;
assign lts_real[12] = 16'h0012;
assign lts_real[13] = 16'hfff1;
assign lts_real[14] = 16'hff4d;
assign lts_real[15] = 16'hffbc;
assign lts_real[16] = 16'hff72;
assign lts_real[17] = 16'h0051;
assign lts_real[18] = 16'h004f;
assign lts_real[19] = 16'hfe99;
assign lts_real[20] = 16'hfdcf;
assign lts_real[21] = 16'hffc0;
assign lts_real[22] = 16'h00ba;
assign lts_real[23] = 16'h0012;
assign lts_real[24] = 16'hffce;
assign lts_real[25] = 16'h0005;
assign lts_real[26] = 16'h00c9;
assign lts_real[27] = 16'hff7c;
assign lts_real[28] = 16'h00ad;
assign lts_real[29] = 16'hfff0;
assign lts_real[30] = 16'hfee7;
assign lts_real[31] = 16'h009f;
assign lts_real[32] = 16'h0047;
assign lts_real[33] = 16'h009f;
assign lts_real[34] = 16'hfee7;
assign lts_real[35] = 16'hfff0;
assign lts_real[36] = 16'h00ad;
assign lts_real[37] = 16'hff7c;
assign lts_real[38] = 16'h00c9;
assign lts_real[39] = 16'h0005;
assign lts_real[40] = 16'hffce;
assign lts_real[41] = 16'h0012;
assign lts_real[42] = 16'h00ba;
assign lts_real[43] = 16'hffc0;
assign lts_real[44] = 16'hfdcf;
assign lts_real[45] = 16'hfe99;
assign lts_real[46] = 16'h004f;
assign lts_real[47] = 16'h0051;
assign lts_real[48] = 16'hff72;
assign lts_real[49] = 16'hffbc;
assign lts_real[50] = 16'hff4d;
assign lts_real[51] = 16'hfff1;
assign lts_real[52] = 16'h0012;
assign lts_real[53] = 16'hffd1;
assign lts_real[54] = 16'hffaa;
assign lts_real[55] = 16'hff8e;
assign lts_real[56] = 16'h0032;
assign lts_real[57] = 16'hff9b;
assign lts_real[58] = 16'hff9c;
assign lts_real[59] = 16'h0015;
assign lts_real[60] = 16'h0057;
assign lts_real[61] = 16'hfe9a;
assign lts_real[62] = 16'h00b4;
assign lts_real[63] = 16'hff6d;

// LTS Imaginary Part (from LTS_imag.txt)
assign lts_imag[0]  = 16'h0000;
assign lts_imag[1]  = 16'h0021;
assign lts_imag[2]  = 16'hffd5;
assign lts_imag[3]  = 16'h0069;
assign lts_imag[4]  = 16'hffc9;
assign lts_imag[5]  = 16'hfff6;
assign lts_imag[6]  = 16'h0060;
assign lts_imag[7]  = 16'hfffe;
assign lts_imag[8]  = 16'hffce;
assign lts_imag[9]  = 16'h017f;
assign lts_imag[10] = 16'h00dc;
assign lts_imag[11] = 16'h0086;
assign lts_imag[12] = 16'h00e0;
assign lts_imag[13] = 16'hff40;
assign lts_imag[14] = 16'h0094;
assign lts_imag[15] = 16'hff0f;
assign lts_imag[16] = 16'hffb9;
assign lts_imag[17] = 16'h0108;
assign lts_imag[18] = 16'hffa2;
assign lts_imag[19] = 16'h009b;
assign lts_imag[20] = 16'hff36;
assign lts_imag[21] = 16'h0007;
assign lts_imag[22] = 16'h0106;
assign lts_imag[23] = 16'hffbb;
assign lts_imag[24] = 16'hffce;
assign lts_imag[25] = 16'h0126;
assign lts_imag[26] = 16'h0037;
assign lts_imag[27] = 16'hfeb7;
assign lts_imag[28] = 16'h0173;
assign lts_imag[29] = 16'h01ab;
assign lts_imag[30] = 16'h00c7;
assign lts_imag[31] = 16'h013c;
assign lts_imag[32] = 16'h0000;
assign lts_imag[33] = 16'hfec4;
assign lts_imag[34] = 16'hff39;
assign lts_imag[35] = 16'hfe55;
assign lts_imag[36] = 16'hfe8d;
assign lts_imag[37] = 16'h0149;
assign lts_imag[38] = 16'hffc9;
assign lts_imag[39] = 16'hfeda;
assign lts_imag[40] = 16'h0032;
assign lts_imag[41] = 16'h0045;
assign lts_imag[42] = 16'hfefa;
assign lts_imag[43] = 16'hfff9;
assign lts_imag[44] = 16'h00ca;
assign lts_imag[45] = 16'hff65;
assign lts_imag[46] = 16'h005e;
assign lts_imag[47] = 16'hfef8;
assign lts_imag[48] = 16'h0047;
assign lts_imag[49] = 16'h00f1;
assign lts_imag[50] = 16'hff6c;
assign lts_imag[51] = 16'h00c0;
assign lts_imag[52] = 16'hff20;
assign lts_imag[53] = 16'hff7a;
assign lts_imag[54] = 16'hff24;
assign lts_imag[55] = 16'hfe81;
assign lts_imag[56] = 16'h0032;
assign lts_imag[57] = 16'h0002;
assign lts_imag[58] = 16'hffa0;
assign lts_imag[59] = 16'h000a;
assign lts_imag[60] = 16'h0037;
assign lts_imag[61] = 16'hff97;
assign lts_imag[62] = 16'h002b;
assign lts_imag[63] = 16'hffdf;

endmodule