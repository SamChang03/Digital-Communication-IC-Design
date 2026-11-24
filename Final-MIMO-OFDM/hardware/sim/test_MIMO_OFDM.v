`timescale 1ns/1ps
`define CYCLE 5
`define END_CYCLE 50000
`define TEST_LENGTH 10000

`define TOTAL_BIT 16
`define QAM_BITLEN 2
`define ATENNA 2

module test_MIMO_OFDM();


reg clk;
reg rst_n;
reg MIMO_OFDM_enable, long_enable;
reg signed[`TOTAL_BIT-1:0] RX_A_re, RX_A_im, RX_B_re, RX_B_im;


reg [`TOTAL_BIT-1:0] RX1_real [0:`TEST_LENGTH-1];
reg [`TOTAL_BIT-1:0] RX1_imag [0:`TEST_LENGTH-1];
reg [`TOTAL_BIT-1:0] RX2_real [0:`TEST_LENGTH-1];
reg [`TOTAL_BIT-1:0] RX2_imag [0:`TEST_LENGTH-1];
reg golden_A [0:2*`TEST_LENGTH-1];
reg golden_B [0:2*`TEST_LENGTH-1];

wire [`QAM_BITLEN-1:0] bits_demapping_A, bits_demapping_B;

wire short_preamble_detected;
wire MIMO_OFDM_valid;

integer i, j;
// ****************************** clock generation *******************************
always #(`CYCLE/2) clk = ~clk; 


// ****************************** block connection *******************************

MIMO_OFDM_top MIMO_OFDM_U0
(
    .clk(clk),
    .rst_n(rst_n),
    .MIMO_OFDM_enable(MIMO_OFDM_enable),

    .RX_A_re(RX_A_re),
    .RX_A_im(RX_A_im),
    .RX_B_re(RX_B_re),
    .RX_B_im(RX_B_im),

    .MIMO_OFDM_valid(MIMO_OFDM_valid),
    .bits_demapping_A(bits_demapping_A),
    .bits_demapping_B(bits_demapping_B)
);
// ********************************** Include SDF ***********************************
initial begin
`ifdef GATESIM
    $fsdbDumpfile("gatesim.fsdb");
    $fsdbDumpvars("+mda", MIMO_OFDM_U0);
	$sdf_annotate("../syn/netlist/MIMO_OFDM_top_syn.sdf",MIMO_OFDM_U0);
`else
    $fsdbDumpfile("presim.fsdb");
    $fsdbDumpvars("+mda", MIMO_OFDM_U0);
`endif
end
// ****************************** input signal *******************************
initial begin
    clk = 0;
    rst_n = 1;
    RX_A_re = 16'b0;
    RX_A_im = 16'b0;
    RX_B_re = 16'b0;
    RX_B_im = 16'b0;
    i = 0;
    j = 0;
    MIMO_OFDM_enable = 0;
    

    #(`CYCLE) rst_n = 0;
    #(`CYCLE) rst_n = 1;
    @(negedge clk); MIMO_OFDM_enable = 1;
    //@(negedge clk); MIMO_OFDM_enable = 0;
    for(i=0;i<`TEST_LENGTH;i=i+1) begin

        RX_A_re = $signed(RX1_real[i]);
        RX_A_im = $signed(RX1_imag[i]);

        RX_B_re = $signed(RX2_real[i]);
        RX_B_im = $signed(RX2_imag[i]);

        @(negedge clk);
    end

   #(`END_CYCLE) $finish;
end

initial
begin
    $fsdbDumpfile("MIMO_OFDM.fsdb");
    $fsdbDumpvars("+mda");
end

initial begin
    $readmemh("data/RX1_real.txt", RX1_real);
    $readmemh("data/RX1_imag.txt", RX1_imag);
    $readmemh("data/RX2_real.txt", RX2_real);
    $readmemh("data/RX2_imag.txt", RX2_imag);

    $readmemh("data/golden_A.txt",golden_A);
    $readmemh("data/golden_B.txt",golden_B);
end


// ******************************** check output ********************************

integer pat_error;
integer output_i=0;
integer print_cnt=0;
integer test_bit=0;

integer file_golden_1, file_golden_2;

initial begin
    pat_error = 0;
    wait(MIMO_OFDM_valid)
    while (output_i<`TEST_LENGTH) begin
        @(negedge clk);
        if(MIMO_OFDM_valid) begin
            for (j = 0 ; j<`QAM_BITLEN ;j=j+1 ) begin
                test_bit = `QAM_BITLEN*output_i + j;
                // Check A
                if(bits_demapping_A[j] !== golden_A[test_bit])begin
                    $display ("!!!!! Comparison Fail @ pattern %0d !!!!!", test_bit);
                    $display(" MyAnswer=%b, Golden=%b", bits_demapping_A[j], golden_A[test_bit]);
                    pat_error = pat_error + 1;
                end
                else begin
                    $display(">>>>> Comparison Pass @ pattern %0d <<<<<", test_bit);
                    $display(" coded=%d  ", golden_A[test_bit]);
                end

                // Check B
                if(bits_demapping_B[j] !== golden_B[test_bit])begin
                    $display ("!!!!! Comparison Fail @ pattern %0d !!!!!", test_bit);
                    $display(" MyAnswer=%b, Golden=%b", bits_demapping_B[j], golden_B[test_bit]);
                    pat_error = pat_error + 1;
                end
                else begin
                    $display(">>>>> Comparison Pass @ pattern %0d <<<<<", test_bit);
                    $display(" coded=%d  ", golden_B[test_bit]);
                end
            end
        output_i =output_i +1;   
        end
        
    end
    if (pat_error === 0) begin
        $display("\n============= Congratulations =============");
        $display(" ");
        $display("             Total %0d Bits Pass ", `QAM_BITLEN*`ATENNA*`TEST_LENGTH);
        $display("            !!! MIMO OFDM PASS !!!");
        $display(" ");
        $display("============= Congratulations =============\n");
    end
    else begin
        $display("\nxxxxxxxxxxx Comparison Fail xxxxxxxxxxx");
        $display("            Total %0d errors\n  Please check your error messages...", pat_error);
        $display("xxxxxxxxxxx Comparison Fail xxxxxxxxxxx\n");
    end
    $display("--- Writing completed. Total 16 Bytes written. ---");

    $finish;
end
// ******************************************************************************


// early termination of simulation 
initial begin
  #(`END_CYCLE*`CYCLE);
  $display("\n============= Error =============");
  $display(  "   Simulation takes too long...  ");
  $display("============= Error =============\n");
  $finish;
end

endmodule