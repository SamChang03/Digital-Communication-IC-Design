function Tx_STS_Time = gen_short_preamble(FFT_SIZE,MODE_IFFT)
% GENERATE_OFDM_PACKET creates a complete OFDM Physical Layer Packet (PPDU).
% This function includes Preamble, SIGNAL field, and 16-QAM Data from a bitstream.
%
% Inputs:
%   Data_Bits: The raw data bitstream (unprocessed payload) to be transmitted.
%   FFT_SIZE, CP_LENGTH: OFDM physical parameters (e.g., 64, 16).
%   CODE_RATE: Coding rate for the data (e.g., 1/2).
%
% Outputs:
%   Tx_Packet: Time-domain signal of the complete PPDU.
%   LTS_Chips: The known Long Training Sequence in the frequency domain.

% --- OFDM System Constants ---
SC_INDICES = [-26:-22, -21:-8, -7:-1, 1:7, 8:20, 21:26]; % 52 Subcarrier indices

% --- 1. Short Training Symbol (STS) - for Coarse Sync ---

% 1.1 STS Frequency Domain Definition
STS_chips = [0, 0, 0, 0, 0, 0, 0, 0, 1+1i, 0, 0, 0, -1-1i, 0, 0, 0, ...
             1+1i, 0, 0, 0, -1-1i, 0, 0, 0, -1-1i, 0, 0, 0, 1+1i, 0, 0, 0, ...
             0, 0, 0, 0, -1-1i, 0, 0, 0, -1-1i, 0, 0, 0, 1+1i, 0, 0, 0, ...
             1+1i, 0, 0, 0, 1+1i, 0, 0, 0, 1+1i, 0, 0, 0, 0, 0, 0, 0]; 
             
STS_chips = sqrt(14/6).*STS_chips.*sqrt(64/52);
% 1.2 IFFT Mapping
Tx_STS_Freq = zeros(FFT_SIZE, 1);
% Map the non-zero STS values to the corresponding subcarrier indices
Tx_STS_Freq(mod(SC_INDICES, FFT_SIZE) + 1) = STS_chips(SC_INDICES + 27);

% 1.3 Time Domain Conversion (IFFT)
Tx_STS_Time_period = SRFFT(Tx_STS_Freq,MODE_IFFT); % Normalized IFFT
Tx_STS_Time = repmat(Tx_STS_Time_period(1:16), 1, 10); % 10 repetitions of 16 samples
Tx_STS_Time = reshape(Tx_STS_Time,[],1);

disp(['Sort Preamble Power: ', num2str(mean(abs(Tx_STS_Time).^2))]);
end