function [Tx_Packet_Mixed, LTS_Chips] = gen_long_preamble(FFT_SIZE, CP_LENGTH,MODE_IFFT)
% ADD_PREAMBLE_LONG generates IEEE 802.11a/g Long Training Sequence (LTS)
%
% Inputs:
%   FFT_SIZE  - Number of IFFT points (typically 64)
%   CP_LENGTH - Cyclic Prefix length (typically 16)
%
% Outputs:
%   Tx_Packet_Mixed - Time-domain two-LTS symbol with CP
%   LTS_Chips       - LTS sequence in frequency domain (52 active subcarriers)

% --- 1. Frequency-domain LTS definition (52 subcarriers) ---
LTS_Chips = [ ...
     1,  1, -1, -1,  1,  1, -1,  1, -1,  1,  1,  1,  1,  1,  1, -1, -1,  1,  1, ...
    -1,  1, -1,  1,  1,  1,  1,  0,  1, -1, -1,  1,  1, -1,  1, -1,  1, -1, -1, ...
    -1, -1, -1,  1,  1, -1, -1,  1, -1,  1, -1,  1,  1,  1,  1 ...
];
LTS_Chips = sqrt(64/52).*LTS_Chips;
% --- 2. Map LTS to 64-point IFFT bins ---
% FFT bin indices: -32 ~ +31, MATLAB index 1~64
Tx_LTS_Freq = zeros(FFT_SIZE, 1);

% Subcarrier mapping (IEEE 802.11 standard):
SC_INDICES = [-26:-1, 1:26];  % 52 subcarriers
Tx_LTS_Freq(mod(SC_INDICES, FFT_SIZE) + 1) = LTS_Chips(1:52);

% --- 3. Convert to time domain ---
Tx_LTS_Time_NoCP = SRFFT(Tx_LTS_Freq,MODE_IFFT);

% --- 4. Add cyclic prefix and duplicate ---
LTS_CP = Tx_LTS_Time_NoCP(end - CP_LENGTH*2 + 1:end);
Tx_Packet_Mixed = [LTS_CP; Tx_LTS_Time_NoCP;Tx_LTS_Time_NoCP];

disp(['Long Preamble Power: ', num2str(mean(abs(Tx_Packet_Mixed).^2))]);
end
