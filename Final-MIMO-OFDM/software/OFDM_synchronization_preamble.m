function [FFTstartIndexPreamble,CoaseFO,FineFO,CoaseAGC] = OFDM_synchronization_preamble(OFDMnoisePreamble,LTS_Chips,FFT_SIZE,CP_LENGTH,MODE_IFFT,SEARCH_WINDOW,fs)
% OFDM Symbol Synchronization with preamble

% Coarse Synchronization (STS)
[STS_start_index,CoaseAGC,CoaseFO] = OFDM_STS_synchronization(OFDMnoisePreamble,FFT_SIZE,SEARCH_WINDOW,fs);

% Auto Gain Control (AGC)
OFDMnoisePreamble = OFDMnoisePreamble * CoaseAGC;

% Frequency Compensation
%OFDMnoisePreamble = OFDMnoisePreamble*exp(-1i);

% Fine Synchronization (LTS)
if STS_start_index > 0
    [First_Data_Start,FineFO] = OFDM_LTS_synchronization( ...
        OFDMnoisePreamble, LTS_Chips, STS_start_index, FFT_SIZE, CP_LENGTH,MODE_IFFT,fs);
    
    FFTstartIndexPreamble = First_Data_Start + FFT_SIZE*2 + 4*CP_LENGTH;
else
    FFTstartIndexPreamble = 1;
    disp('Synchronization Failed at STS stage.');
end