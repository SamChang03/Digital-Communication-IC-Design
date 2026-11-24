function demapped_bits = QPSK_demapping(FFTSymbols)
% QPSK Demapping

%% Preparation
% Change FFT Matrix to 1-D Array
TranFFTSymbols= FFTSymbols.';
SymbolsSerial = TranFFTSymbols(:);
numSymbols = length(SymbolsSerial);

% Default Array
demapped_bits = zeros(numSymbols * 2, 1, 'logical');

% Complex Number Decomposition
I_data = real(SymbolsSerial);
Q_data = imag(SymbolsSerial);

%% Determine Output b1b0
% --- MSB (b1): I-Axis ---
b1 = (I_data > 0); 

% --- LSB (b0): Q-Axis ---
b0 = (Q_data < 0);

%% Combine bitstream
% b1 in odd position (1, 3, 5, ...)
demapped_bits(1:2:end) = b1; 
% b0 in even position (2, 4, 6, ...)
demapped_bits(2:2:end) = b0; 

%% Check Out
%disp(['Demapping Completed. Total Bits for RX: ', num2str(length(demapped_bits))]);
end