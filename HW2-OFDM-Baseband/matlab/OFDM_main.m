clc
clear
%Main Function of OFDM System
%% Parameters Setting 
numBits = 2^20; % 33,554,432 bits
M = 16; % M-QAM --> M=4: QPSK; M=16: 16-QAM
FFTsize = 64; % FFT Size
SNR_dB = 24; % SNR
CP_Ratio = 1/4; %CP Ratio
AutoNum = 20; % Determine gruop number for autocorrelation;
              % Not too small > 15

MODE_FFT = -1;
MODE_IFFT = 1;

%% Bit Stream Generation 
bitStream = bit_stream_generation(numBits);

%% QAM Mapping
modulatedSymbols = QAM_mapping(bitStream,M);

%% Serial to 64xParallel
paralleldSymbols = Serial_to_64xParallel (modulatedSymbols,FFTsize);

%% IFFT
numGroup = numBits/log2(M)/FFTsize;
IFFTSymbols = zeros(numGroup,FFTsize);

for i=1:numGroup
    IFFTSymbols(i,:) = SRFFT(paralleldSymbols(i,:), MODE_IFFT);
    %IFFTSymbols(i,:) = ifft(paralleldSymbols(i,:), MODE_IFFT);
end

%%%%% Test IFFT %%%%%
%IFFTSymbolsTest = zeros(numGroup,FFTsize);

%for i=1:numGroup
%    IFFTSymbolsTest(i,:) = ifft(paralleldSymbols(i,:));
%end
%%%%% End Test %%%%%

%% CP insertion
numCP = FFTsize* CP_Ratio;
CP_data = IFFTSymbols(:, (FFTsize - numCP + 1) : FFTsize);
OFDMsymbolCp = [CP_data,IFFTSymbols];

%% 64xParallel to serial
OFDMSerial = Parallelx64_to_serial (OFDMsymbolCp);

%% AWGN channel
%OFDMnoise = OFDMSerial;
OFDMnoise = AWGN_channel(OFDMSerial,SNR_dB);

%% OFDM Sym.synchronization
FFTstartIndex = OFDM_symbol_synchronization(OFDMnoise,FFTsize,numCP,AutoNum);

%% CP Removal
OFDMsymbol=CP_Removal(OFDMnoise,FFTstartIndex,FFTsize,numCP,numGroup);

%% FFT
FFTSymbols = zeros(numGroup,FFTsize);
for i=1:numGroup
    FFTSymbols(i,:) = SRFFT(OFDMsymbol(i,:), MODE_FFT);
    %FFTSymbols(i,:) = fft(OFDMsymbol(i,:));
end

%%%%% Test FFT %%%%%
%FFTSymbolsTest = zeros(numGroup,FFTsize);

%for i=1:numGroup
%    FFTSymbolsTest(i,:) = fft(OFDMsymbol(i,:));
%end
%%%%% End Test %%%%%

%% QAM Demapping
if M==4
    bitsDemapped = QPSK_demapping(FFTSymbols).';
elseif M==16
    bitsDemapped = QAM16_demapping(FFTSymbols).';
end
%% Bit Error Rate Calculation

error_vector = (bitStream ~= bitsDemapped);
N_errors = sum(error_vector);

BER = N_errors / numBits*100;

disp(['Error Bits: ', num2str(N_errors)]);
disp(['Bit Error Rate (BER):', num2str(BER)]);

%% Plot 

%%%%%%%%%%%%%%%%%% OFDM Symbols %%%%%%%%%%%%%%%%%%%%%%%%%%
figure(1)
plot(real(OFDMSerial(1:3*(FFTsize+numCP))),'LineWidth',2)
hold on
plot(real(OFDMnoise(1:3*(FFTsize+numCP))),'LineWidth',2)

% Sym.1
xline(1, '--', 'LineWidth', 2, 'Label', 'Sym.1 CP','LabelOrientation','horizontal','FontSize',10)
xline(17, '--', 'LineWidth', 2, 'Label', 'Sym.1 Data','LabelOrientation','horizontal','FontSize',10)
% Sym.2
xline(81, '--', 'LineWidth', 2, 'Label', 'Sym.2 CP','LabelOrientation','horizontal','FontSize',10)
xline(97, '--', 'LineWidth', 2, 'Label', 'Sym.2 Data','LabelOrientation','horizontal','FontSize',10)
% Sym.3
xline(161, '--', 'LineWidth', 2, 'Label', 'Sym.3 CP','LabelOrientation','horizontal','FontSize',10)
xline(177, '--', 'LineWidth', 2, 'Label', 'Sym.3 Data','LabelOrientation','horizontal','FontSize',10)
xline(240, '--', 'LineWidth', 2, 'Label', 'Sym.3 end','LabelOrientation','horizontal','FontSize',10)

set(gca, 'FontSize', 16);
xlabel('Time', 'FontSize', 16);
ylabel('y', 'FontSize', 16);
title('OFDM Symbols SNR = ')
legend('Before AWGN','After AWGN')

figure(2)
plot(real(OFDMSerial(1:3*(FFTsize+numCP))),'LineWidth',2)

% Sym.1
xline(1, '--', 'LineWidth', 2, 'Label', 'Sym.1 CP','LabelOrientation','horizontal','FontSize',10)
xline(17, '--', 'LineWidth', 2, 'Label', 'Sym.1 Data','LabelOrientation','horizontal','FontSize',10)
% Sym.2
xline(81, '--', 'LineWidth', 2, 'Label', 'Sym.2 CP','LabelOrientation','horizontal','FontSize',10)
xline(97, '--', 'LineWidth', 2, 'Label', 'Sym.2 Data','LabelOrientation','horizontal','FontSize',10)
% Sym.3
xline(161, '--', 'LineWidth', 2, 'Label', 'Sym.3 CP','LabelOrientation','horizontal','FontSize',10)
xline(177, '--', 'LineWidth', 2, 'Label', 'Sym.3 Data','LabelOrientation','horizontal','FontSize',10)
xline(240, '--', 'LineWidth', 2, 'Label', 'Sym.3 end','LabelOrientation','horizontal','FontSize',10)

set(gca, 'FontSize', 16);
xlabel('Time', 'FontSize', 16);
ylabel('y', 'FontSize', 16);
title('OFDM Symbols SNR = ')
legend('Before AWGN')

%%%%%%%%%%%%%%%%%% Constellation %%%%%%%%%%%%%%%%%%%%%%%%%%
h = comm.ConstellationDiagram('NumInputPorts', 1, ...
                              'XLimits',[-1.5,1.5],'YLimits',[-1.5,1.5]);
h.ReferenceConstellation = 0;
h(FFTSymbols(1:3,:)');

%%%%%%%%%%%%%%%%%% BER Comparision %%%%%%%%%%%%%%%%%%%%%%%%%%
figure(3)
x = 0:3:24;
BER_QPSK = [49.95,7.945,2.311,0.24,0.003,0,0,0,0];
BER_16QAM = [47.09,21.26,14.16,7.61,2.8,0.45,0.001,0,0];

plot(x,BER_QPSK,'-o',x,BER_16QAM,'-*')

set(gca, 'FontSize', 16);
xlabel('SNR', 'FontSize', 16);
ylabel('BER', 'FontSize', 16);
title('BER Compasision')
legend('BER QPSK','BER 16-QAM')