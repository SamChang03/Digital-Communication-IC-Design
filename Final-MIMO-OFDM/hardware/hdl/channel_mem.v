module channel_mem #
(
    parameter FIFO_LENGTH = 64,
    parameter FIFO_WIDTH_LOG  = 5,
    parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8,
    parameter ADDR_BIT = 6
)
(
    input clk,
    //input read_en,
    input write_en,
    input [ADDR_BIT-1:0] read_addr,
    input [ADDR_BIT-1:0] write_addr,
    
    input signed [TOTAL_BIT-1:0] data_in_re, data_in_im,

    output reg signed [TOTAL_BIT-1:0] data_out_re, data_out_im
);

reg [TOTAL_BIT-1:0] mem_real [0:FIFO_LENGTH-1];
reg [TOTAL_BIT-1:0] mem_imag [0:FIFO_LENGTH-1];

always @(posedge clk) begin
    if (write_en) begin
        mem_real[write_addr] <= data_in_re;
        mem_imag[write_addr] <= data_in_im;
    end

    data_out_re <= mem_real[read_addr];
    data_out_im <= mem_imag[read_addr];
end

endmodule