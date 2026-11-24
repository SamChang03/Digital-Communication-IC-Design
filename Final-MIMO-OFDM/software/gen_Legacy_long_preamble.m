function [Tx_Packet_Mixed, LTS_Chips] = gen_Legacy_long_preamble(CP_LENGTH,MODE_IFFT)
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
    -1, 1, 1, 1, -1, 1, -1, 1, 1, 1, -1, 1, 1, -1, 1, 1, ... % k=-31 to -17
    1, -1, 1, -1, -1, 1, -1, 1, 1, 1, -1, 1, 1, 1, 1, 1, ... % k=-16 to 0 (DC)
    1, 1, 1, 1, -1, 1, 1, 1, -1, -1, 1, -1, 1, -1, 1, 1, ... % k=1 to 16
    -1, 1, 1, -1, 1, 1, 1, -1, 1, -1, 1, 1, 1, -1, 1, -1 ...  % k=17 to 32
];

LTS_Chips = LTS_Chips.';
% --- 3. Convert to time domain ---
Tx_LTS_Time_NoCP = SRFFT(LTS_Chips,MODE_IFFT);

% --- 4. Add cyclic prefix and duplicate ---
LTS_CP = Tx_LTS_Time_NoCP(end - CP_LENGTH*2 + 1:end);
Tx_Packet_Mixed = [LTS_CP; Tx_LTS_Time_NoCP;Tx_LTS_Time_NoCP];

disp(['Long Preamble Power: ', num2str(mean(abs(Tx_Packet_Mixed).^2))]);
end
