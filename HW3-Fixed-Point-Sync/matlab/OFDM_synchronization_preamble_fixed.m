function FFTstartIndexPreamble = OFDM_synchronization_preamble_fixed(OFDMnoisePreamble,LTS_Chips,FFT_SIZE,CP_LENGTH,MODE_IFFT,SEARCH_WINDOW,int_bit,frac_bit)
% OFDM Symbol Synchronization with preamble

% Coarse Synchronization (STS)
OFDMnoisePreamble = truncation(OFDMnoisePreamble,int_bit,frac_bit);
STS_start_index = OFDM_STS_synchronization_fixed(OFDMnoisePreamble,FFT_SIZE,SEARCH_WINDOW,int_bit,frac_bit);

% Fine Synchronization (LTS)
if STS_start_index > 0
    First_Data_Start = OFDM_LTS_synchronization_fixed( ...
        OFDMnoisePreamble, LTS_Chips, STS_start_index, FFT_SIZE, CP_LENGTH,MODE_IFFT,int_bit,frac_bit);
    
    FFTstartIndexPreamble = First_Data_Start + CP_LENGTH;
else
    FFTstartIndexPreamble = 1;
    disp('Synchronization Failed at STS stage.');
end