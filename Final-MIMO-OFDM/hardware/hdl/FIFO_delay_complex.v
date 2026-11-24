module FIFO_delay_complex #(
    parameter FIFO_LENGTH = 32,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
) (
    input clk,
    input rst_n,

    input                               enable,  
    input signed [TOTAL_BIT-1:0]        data_in_re,
    input signed [TOTAL_BIT-1:0]        data_in_im,

    output signed [TOTAL_BIT-1:0]       data_out_re, // delay "FIFO_LENGTH" Cycle
    output signed [TOTAL_BIT-1:0]       data_out_im // delay "FIFO_LENGTH" Cycle
);

integer i;
// -------------------------------- //
//          FIFO Memories           //
// -------------------------------- //
reg [TOTAL_BIT-1:0] FIFO_real [0:FIFO_LENGTH-1];
reg [TOTAL_BIT-1:0] FIFO_imag [0:FIFO_LENGTH-1];

// -------------------------------- //
//          Delay Logic             //
// -------------------------------- //

assign data_out_re = FIFO_real[FIFO_LENGTH-1];
assign data_out_im = FIFO_imag[FIFO_LENGTH-1];

always @(posedge clk) begin
    
    if (~rst_n) begin
        for (i=0; i<FIFO_LENGTH; i=i+1) begin
            FIFO_real[i] <= 0;
            FIFO_imag[i] <= 0;
        end
    end 
    else if (enable) begin
        FIFO_real[0] <= data_in_re;
        FIFO_imag[0] <= data_in_im;

        for ( i=1 ; i<FIFO_LENGTH ; i=i+1 ) begin
            FIFO_real[i] <= FIFO_real[i-1];
            FIFO_imag[i] <= FIFO_imag[i-1];
        end
    end
end

endmodule