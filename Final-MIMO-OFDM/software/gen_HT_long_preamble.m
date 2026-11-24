function [Tx_Packet_Mixed, LTS_Chips] = gen_HT_long_preamble(CP_LENGTH,MODE_IFFT, Antenna)
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

LTS_Chips_even = [ ...
    0,  1, 0,  1,  0, 1, 0,  1, 0,  1, 0,  1, 0, -1, 0, 1, ... % k=-31 to -17
    0, -1, 0, -1,  0, 1, 0,  1, 0,  1, 0,  1, 0,  1, 0, 1, ... % k=-16 to 0 (DC)
    0,  1, 0,  1,  0, 1, 0,  1, 0, -1, 0, -1, 0, -1, 0, 1, ... % k=1 to 16
    0,  1, 0, -1,  0, 1, 0, -1, 0, -1, 0,  1, 0, -1, 0, -1 ...  % k=17 to 32
];

LTS_Chips_odd = [ ...
    -1, 0, 1, 0, -1, 0, -1, 0,  1, 0, -1, 0, 1, 0, 1, 0, ... % k=-31 to -17
     1, 0, 1, 0, -1, 0, -1, 0,  1, 0, -1, 0, 1, 0, 1, 0, ... % k=-16 to 0 (DC)
     1, 0, 1, 0, -1, 0,  1, 0, -1, 0,  1, 0, 1, 0, 1, 0, ... % k=1 to 16
    -1, 0, 1, 0,  1, 0,  1, 0,  1, 0,  1, 0, 1, 0, 1, 0 ...  % k=17 to 32
];

%LTS_Chips_even = ones(64,1).';
%LTS_Chips_odd = ones(64,1).';

%LTS_Chips_even = [zeros(32,1); ones(32,1)].';
%LTS_Chips_odd = [zeros(32,1); ones(32,1)].';

if Antenna == 0
    LTS_Chips = LTS_Chips_even.';
else
    LTS_Chips = LTS_Chips_odd.';
end

% --- 3. Convert to time domain ---
Tx_LTS_Time_NoCP = SRFFT(LTS_Chips,MODE_IFFT);

% --- 4. Add cyclic prefix and duplicate ---
LTS_CP = Tx_LTS_Time_NoCP(end - CP_LENGTH*2 + 1:end);

Tx_Packet_Mixed = [LTS_CP; Tx_LTS_Time_NoCP;Tx_LTS_Time_NoCP];

disp(['Long Preamble Power: ', num2str(mean(abs(Tx_Packet_Mixed).^2))]);
end
