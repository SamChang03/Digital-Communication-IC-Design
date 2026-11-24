module Rotator #(
    parameter CNT_WIDTH = 6, 
    parameter TOTAL_BIT = 16, 
    parameter FRAC_BIT  = 8
) (
    input wire clk, 
    input wire rst_n, 
    input wire valid_in,
    input wire signed [TOTAL_BIT-1:0] data_in_re, data_in_im,
    
    output reg valid_out,
    output reg signed [TOTAL_BIT-1:0] data_out_re, data_out_im
);

    // =========================================================
    // 1. Counter Logic (0 to 63)
    // =========================================================
    reg [CNT_WIDTH-1:0] cnt;
    
    always @(posedge clk) begin
        if (~rst_n) begin
            cnt <= 0;
        end 
        else begin
            if (valid_in) begin
                cnt <= cnt + 1; // Auto-wrap 0~63
            end 
            else begin
                cnt <= 0; // Reset counter on data interruption
            end
        end
    end

    // =========================================================
    // 2. Address Generation
    // =========================================================
    // Formula: addr = (Permuted_Group_Index) * (Sub_Index)
    // Group_Index = cnt[5:3]
    // Sub_Index   = cnt[2:0]
    
    wire [2:0] group_idx = cnt[5:3];
    wire [2:0] sub_idx   = cnt[2:0];
    
    wire [CNT_WIDTH-1:0] rom_addr;
    reg [2:0] group_idx_real;

    // Bit-reversal permutation for the group index
    always @(*) begin
        group_idx_real = 0;
        case (group_idx)
            0: group_idx_real = 0;
            1: group_idx_real = 4;
            2: group_idx_real = 2;
            3: group_idx_real = 6;
            4: group_idx_real = 1;
            5: group_idx_real = 5;
            6: group_idx_real = 3;
            7: group_idx_real = 7;
        endcase
    end

    // 3-bit * 3-bit multiplication for address calculation.
    // Note: Pure combinational logic. May require pipelining at high frequencies.
    assign rom_addr = group_idx_real * sub_idx;

    // =========================================================
    // 3. ROM Lookup & Multiplication
    // =========================================================
    wire signed [TOTAL_BIT-1:0] wn_re, wn_im;
    
    // Look up Twiddle Factor based on calculated address
    Twiddle_ROM #(.ADDR_WIDTH(CNT_WIDTH)) rom (
        .addr(rom_addr),
        .wn_re(wn_re), .wn_im(wn_im)
    );
    
    wire signed [TOTAL_BIT-1:0] mult_out_re, mult_out_im;

    // Complex Multiplication: Data_in * Wn
    complex_mult mult (
        .din_re(data_in_re), .din_im(data_in_im), 
        .din_2_re(wn_re), .din_2_im(wn_im), 
        .dout_re(mult_out_re), .dout_im(mult_out_im)
    );

    // =========================================================
    // 4. Output Register (Pipeline Stage)
    // =========================================================
    always @(posedge clk) begin
        if(~rst_n) begin 
            valid_out <= 0; 
            data_out_re <= 0;
            data_out_im <= 0;
        end else begin
            // Register output to align with 1-cycle latency
            valid_out   <= valid_in;
            data_out_re <= mult_out_re;
            data_out_im <= mult_out_im;
        end
    end

endmodule

module Twiddle_ROM #(parameter ADDR_WIDTH=6) (input [ADDR_WIDTH-1:0] addr, output reg signed [15:0] wn_re, wn_im);
    always @(*) begin
        // For N=64, W_64^k. Scale factor: 256
        case(addr)
            // Quadrant 1 (0 to ~90 deg)
            6'd0:  begin wn_re =  256; wn_im =    0; end // 0.0 deg
            6'd1:  begin wn_re =  255; wn_im =  -25; end 
            6'd2:  begin wn_re =  251; wn_im =  -50; end 
            6'd3:  begin wn_re =  245; wn_im =  -74; end 
            6'd4:  begin wn_re =  237; wn_im =  -98; end 
            6'd5:  begin wn_re =  226; wn_im = -121; end 
            6'd6:  begin wn_re =  213; wn_im = -142; end 
            6'd7:  begin wn_re =  198; wn_im = -162; end 
            
            6'd8:  begin wn_re =  181; wn_im = -181; end // 45.0 deg
            
            6'd9:  begin wn_re =  162; wn_im = -198; end 
            6'd10: begin wn_re =  142; wn_im = -213; end 
            6'd11: begin wn_re =  121; wn_im = -226; end 
            6'd12: begin wn_re =   98; wn_im = -237; end 
            6'd13: begin wn_re =   74; wn_im = -245; end 
            6'd14: begin wn_re =   50; wn_im = -251; end 
            6'd15: begin wn_re =   25; wn_im = -255; end 
            
            // Quadrant 2 (~90 to ~180 deg)
            6'd16: begin wn_re =    0; wn_im = -256; end // 90.0 deg (-j)
            
            6'd17: begin wn_re =  -25; wn_im = -255; end 
            6'd18: begin wn_re =  -50; wn_im = -251; end 
            6'd19: begin wn_re =  -74; wn_im = -245; end 
            6'd20: begin wn_re =  -98; wn_im = -237; end 
            6'd21: begin wn_re = -121; wn_im = -226; end 
            6'd22: begin wn_re = -142; wn_im = -213; end 
            6'd23: begin wn_re = -162; wn_im = -198; end 
            
            6'd24: begin wn_re = -181; wn_im = -181; end // 135.0 deg
            
            6'd25: begin wn_re = -198; wn_im = -162; end 
            6'd26: begin wn_re = -213; wn_im = -142; end 
            6'd27: begin wn_re = -226; wn_im = -121; end 
            6'd28: begin wn_re = -237; wn_im =  -98; end 
            6'd29: begin wn_re = -245; wn_im =  -74; end 
            6'd30: begin wn_re = -251; wn_im =  -50; end 
            6'd31: begin wn_re = -255; wn_im =  -25; end 
            
            // Quadrant 3 (~180 to ~270 deg)
            6'd32: begin wn_re = -256; wn_im =    0; end // 180.0 deg (-1)
            
            6'd33: begin wn_re = -255; wn_im =   25; end 
            6'd34: begin wn_re = -251; wn_im =   50; end 
            6'd35: begin wn_re = -245; wn_im =   74; end 
            6'd36: begin wn_re = -237; wn_im =   98; end 
            6'd37: begin wn_re = -226; wn_im =  121; end 
            6'd38: begin wn_re = -213; wn_im =  142; end 
            6'd39: begin wn_re = -198; wn_im =  162; end 
            
            6'd40: begin wn_re = -181; wn_im =  181; end // 225.0 deg
            
            6'd41: begin wn_re = -162; wn_im =  198; end 
            6'd42: begin wn_re = -142; wn_im =  213; end 
            6'd43: begin wn_re = -121; wn_im =  226; end 
            6'd44: begin wn_re =  -98; wn_im =  237; end 
            6'd45: begin wn_re =  -74; wn_im =  245; end 
            6'd46: begin wn_re =  -50; wn_im =  251; end 
            6'd47: begin wn_re =  -25; wn_im =  255; end 
            
            // Quadrant 4 (~270 to ~360 deg)
            6'd48: begin wn_re =    0; wn_im =  256; end // 270.0 deg (j)
            
            6'd49: begin wn_re =   25; wn_im =  255; end 
            6'd50: begin wn_re =   50; wn_im =  251; end 
            6'd51: begin wn_re =   74; wn_im =  245; end 
            6'd52: begin wn_re =   98; wn_im =  237; end 
            6'd53: begin wn_re =  121; wn_im =  226; end 
            6'd54: begin wn_re =  142; wn_im =  213; end 
            6'd55: begin wn_re =  162; wn_im =  198; end 
            
            6'd56: begin wn_re =  181; wn_im =  181; end // 315.0 deg
            
            6'd57: begin wn_re =  198; wn_im =  162; end 
            6'd58: begin wn_re =  213; wn_im =  142; end 
            6'd59: begin wn_re =  226; wn_im =  121; end 
            6'd60: begin wn_re =  237; wn_im =   98; end 
            6'd61: begin wn_re =  245; wn_im =   74; end 
            6'd62: begin wn_re =  251; wn_im =   50; end 
            6'd63: begin wn_re =  255; wn_im =   25; end 
            
            default: begin wn_re = 256; wn_im = 0; end
        endcase
    end
endmodule