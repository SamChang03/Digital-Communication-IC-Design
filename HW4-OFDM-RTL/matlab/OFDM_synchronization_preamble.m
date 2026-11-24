function FFTstartIndexPreamble = OFDM_synchronization_preamble(OFDMnoisePreamble,LTS_Chips,FFT_SIZE,CP_LENGTH,MODE_IFFT,SEARCH_WINDOW)
% OFDM Symbol Synchronization with preamble

% Coarse Synchronization (STS)
STS_start_index = OFDM_STS_synchronization(OFDMnoisePreamble,FFT_SIZE,SEARCH_WINDOW);

% Fine Synchronization (LTS)
if STS_start_index > 0
    First_Data_Start = OFDM_LTS_synchronization( ...
        OFDMnoisePreamble, LTS_Chips, STS_start_index, FFT_SIZE, CP_LENGTH,MODE_IFFT);
    
    FFTstartIndexPreamble = First_Data_Start + CP_LENGTH;
else
    FFTstartIndexPreamble = 1;
    disp('Synchronization Failed at STS stage.');
end