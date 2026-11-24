module FIFO_delay #(
    parameter FIFO_LENGTH = 32,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8
) (
    input clk,
    input rst_n,

    input                               enable,  
    input signed [TOTAL_BIT-1:0]        data_in,

    output signed [TOTAL_BIT-1:0]       data_out // delay "FIFO_LENGTH" Cycle
);

integer i;
// -------------------------------- //
//          FIFO Memories           //
// -------------------------------- //
reg [TOTAL_BIT-1:0] FIFO_reg [0:FIFO_LENGTH-1];

// -------------------------------- //
//          Delay Logic             //
// -------------------------------- //

assign data_out = FIFO_reg[FIFO_LENGTH-1];

always @(posedge clk) begin
    if (~rst_n) begin
        for (i=0; i<FIFO_LENGTH; i=i+1) begin
            FIFO_reg[i] <= 0;
        end
    end 
    else if (enable) begin
        FIFO_reg[0] <= data_in;

        for ( i=1 ; i<FIFO_LENGTH ; i=i+1 ) begin
            FIFO_reg[i] <= FIFO_reg[i-1];
        end
    end
end

endmodule