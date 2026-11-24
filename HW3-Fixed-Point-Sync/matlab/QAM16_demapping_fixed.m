function demapped_bits = QAM16_demapping_fixed(FFTSymbols,int_bit,frac_bit)
% 16-QAM Demapping

%% Preparation
Threshold16QAM = truncation(2/sqrt(10),int_bit,frac_bit);

% Change FFT Matrix to 1-D Array
TranFFTSymbols= FFTSymbols.';
SymbolsSerial = TranFFTSymbols(:);
numSymbols = length(SymbolsSerial);

% Default Array
demapped_bits = zeros(numSymbols * 4, 1, 'logical');

% Complex Number Decomposition
I_data = real(SymbolsSerial);
Q_data = imag(SymbolsSerial);

%% Determine Output b0b1b2b3
% --- MSB (b1): I-Axis ---
b0 = (I_data > 0);
b1 = (I_data < Threshold16QAM) & (I_data > -1*Threshold16QAM);

% --- LSB (b0): Q-Axis ---
b2 = (Q_data < 0);
b3 = (Q_data < Threshold16QAM) & (Q_data > -1*Threshold16QAM);

%% Combine bitstream
% b0 in (1, 5, 9, ...)
demapped_bits(1:4:end) = b0; 
% b1 in (2, 6, 10, ...)
demapped_bits(2:4:end) = b1; 
% b2 in (3, 7, 11, ...)
demapped_bits(3:4:end) = b2; 
% b3 in (4, 8, 12, ...)
demapped_bits(4:4:end) = b3; 

%% Check Out
%disp(['Demapping Completed. Total Bits for RX: ', num2str(length(demapped_bits))]);
end