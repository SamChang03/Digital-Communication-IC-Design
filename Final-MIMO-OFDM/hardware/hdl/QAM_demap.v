
module QAM_demap #(
	parameter TOTAL_BIT = 16,
    parameter FRAC_BIT = 8,
	parameter QAM_NUM = 4,
	parameter QAM_BITLEN = 2
) (
	input clk,
	input rst_n,
	input [TOTAL_BIT-1:0] QAM_in_re,
	input [TOTAL_BIT-1:0] QAM_in_im,
	input QAM_valid,

	output reg QAM_ready,
	output reg [QAM_BITLEN-1:0] QAM_out_bit
);
wire msb = (QAM_in_im[TOTAL_BIT-1]) ;
wire lsb = ~(QAM_in_re[TOTAL_BIT-1]) ;


always @(posedge clk) begin
	if (~rst_n) begin
		QAM_out_bit <= 0;
	end
	else begin
		QAM_out_bit <= {msb,lsb};
	end
	QAM_ready <= QAM_valid;
end
	
endmodule



