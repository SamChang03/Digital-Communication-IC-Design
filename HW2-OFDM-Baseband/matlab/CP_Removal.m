function OFDMsymbol=CP_Removal(OFDMnoise,FFTstartIndex,FFTsize,numCP,numGroup)
% CP Removal & S/P

%% Signal Extand
OFDMnoiseLength = length(OFDMnoise);
OFDMnoiseExtand = [OFDMnoise;OFDMnoise(OFDMnoiseLength-FFTsize:OFDMnoiseLength)];

%% Create Index Array
% Create OFDM Symbol Index
symbolIndex = FFTstartIndex : (FFTstartIndex + FFTsize - 1);

% Create offsets array [0; 80; 160; ...]
numSymbolOFDM = FFTsize + numCP;
offsets = (0 : (numGroup - 1)) * numSymbolOFDM;
offsets = offsets.';

% Combine "OFDM Symbol Index" & "offsets array" --> Index Matrix
result_indices = offsets + symbolIndex;

% Index Matrix --> Index Array
result_indices_trans = result_indices.';
finalIndex = result_indices_trans(:).';

%% Remove CP 
Rx_symbol_no_CP_serial = OFDMnoiseExtand(finalIndex); 

%% Serial to Parallel
OFDMsymbol = reshape(Rx_symbol_no_CP_serial, FFTsize, numGroup).';

end