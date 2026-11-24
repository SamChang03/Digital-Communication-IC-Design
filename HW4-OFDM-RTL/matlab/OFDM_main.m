clc
clear

%% Parameters Setting %%
%General Parameters
numBits = 2^15; % 33,554,432 bits
M = 4; % M-QAM --> M=4: QPSK; M=16: 16-QAM
FFT_SIZE = 64;
SNR_dB = 200;
CP_RATIO = 1/4;
CP_LENGTH = FFT_SIZE*CP_RATIO;
AutoNum = 20;
SEARCH_WINDOW = 400;
STS_Len = 10 * (FFT_SIZE / 4);
LTS_Len = FFT_SIZE + CP_LENGTH;

%FFT Mode
MODE_FFT = -1;
MODE_IFFT = 1;

% Exponential LUT
k = -FFT_SIZE+1:FFT_SIZE;
n = FFT_SIZE;
angle = 2 * pi * k./n;
EXP_LUT = exp(1i*angle);

%Fixed Point Simulation
min_interval = 0;
max_interval = 15;
TEST_INVERVAL = min_interval:max_interval; % Test inteval for fixed point sim.
TEST_LENGTH = length(TEST_INVERVAL);
num_test_correlation = 1; % 1 for normalcase; N for N Times OFDM Simulation
                            %  (Include floating and fixed-point )
int_bit = 12; % Set integer bits (set it as TEST_INVERVAL for iteration test)
frac_bit = 8; % Set integer bits (set it as TEST_INVERVAL for iteration test)

%Fixed Point Simulation
test_correlation_fixed = 0;
test_correlation_foating = 0;

for num_test_correlation=1:num_test_correlation
    disp('############# Start OFDM Simulation #############');
    %% Bit Stream Generation %%
    bitStream = bit_stream_generation(numBits);
    
    %% QAM Mapping
    modulatedSymbols = QAM_mapping(bitStream,M);
    
    %% Serial to 64xParallel
    paralleldSymbols = Serial_to_64xParallel (modulatedSymbols,FFT_SIZE);
    
    %% IFFT
    numGroup = numBits/log2(M)/FFT_SIZE;
    IFFTSymbols = zeros(numGroup,FFT_SIZE);
    
    for i=1:numGroup
        IFFTSymbols(i,:) = SRFFT(paralleldSymbols(i,:), MODE_IFFT);
    end
    
    %% CP insertion
    CP_data = IFFTSymbols(:, (FFT_SIZE - CP_LENGTH + 1) : FFT_SIZE);
    OFDMsymbolCp = [CP_data,IFFTSymbols];
    
    %% 64xParallel to serial
    OFDMSerial = Parallelx64_to_serial (OFDMsymbolCp);
    
    %% Add Preamble
    PreamlbeShort = gen_short_preamble(FFT_SIZE, MODE_IFFT);
    [PreamlbeLong,LTS_Chips] = gen_long_preamble(FFT_SIZE,CP_LENGTH, MODE_IFFT);
    
    OFDMSerialPreamble = [OFDMSerial(1:FFT_SIZE);PreamlbeShort;PreamlbeLong;OFDMSerial];
    
    %% AWGN channel
    OFDMnoisePreamble = AWGN_channel(OFDMSerialPreamble,SNR_dB);
    
    %% OFDM Synchronization (FLOATING POINT)
    FFTstartIndexPreamble = ...
        OFDM_synchronization_preamble(OFDMnoisePreamble,LTS_Chips,FFT_SIZE,CP_LENGTH,MODE_IFFT,SEARCH_WINDOW);
    
    %% CP Removal
    OFDMsymbol=CP_Removal(OFDMnoisePreamble,FFTstartIndexPreamble,FFT_SIZE,CP_LENGTH,numGroup);
    
    %% FFT (FLOATING POINT)
    FFTSymbols = zeros(numGroup,FFT_SIZE);
    for i=1:numGroup
        FFTSymbols(i,:) = SRFFT(OFDMsymbol(i,:), MODE_FFT);
    end
    
    %% QAM Demapping (FLOATING POINT)
    if M==4
        bitsDemapped = QPSK_demapping(FFTSymbols).'; % (DO NOT NEED FIXED POINT)
    elseif M==16
        bitsDemapped = QAM16_demapping(FFTSymbols).';
    end
    %% Bit Error Rate Calculation
    
    error_vector = (bitStream ~= bitsDemapped);
    N_errors_floating = sum(error_vector);
    
    BER_Floating = N_errors_floating / numBits*100;
    
    %% %%%%%%%%%%%%%%%%%%% FIXED POINT SIMULATION START %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Parameter Setting
    BER_fixed_point = 0;
    BER_fixed_matrix = zeros(TEST_LENGTH,TEST_LENGTH);
    for int_bit = int_bit
        for frac_bit = frac_bit
        % OFDM Sym.synchronization With Preamble (FIXED POINT)
        FFTstartIndexPreamble = ...
            OFDM_synchronization_preamble_fixed(OFDMnoisePreamble,LTS_Chips,FFT_SIZE,CP_LENGTH,MODE_IFFT,SEARCH_WINDOW,int_bit,frac_bit);
            
        %FFTstartIndexPreamble = ...
            OFDM_synchronization_preamble(OFDMnoisePreamble,LTS_Chips,FFT_SIZE,CP_LENGTH,MODE_IFFT,SEARCH_WINDOW);
        % CP Removal (DO NOT NEED FIXED POINT)
        OFDMsymbol=CP_Removal(OFDMnoisePreamble,FFTstartIndexPreamble,FFT_SIZE,CP_LENGTH,numGroup);
        
        % FFT (FIXED POINT)
        FFTSymbols = zeros(numGroup,FFT_SIZE);
        for i=1:numGroup
            FFTSymbols(i,:) = SRFFT_fixed(OFDMsymbol(i,:), MODE_FFT,int_bit,frac_bit); % Fixed
            %FFTSymbols(i,:) = SRFFT(OFDMsymbol(i,:), MODE_FFT); % Floating
        end
        
        % QAM Demapping (FIXED POINT)
        if M==4
            bitsDemapped = QPSK_demapping(FFTSymbols).'; % DO NOT NEED FIXED POINT
        elseif M==16
            bitsDemapped = QAM16_demapping_fixed(FFTSymbols,int_bit,frac_bit).'; % Fixed
            %bitsDemapped = QAM16_demapping(FFTSymbols).'; % Floating
        end
        % Bit Error Rate Calculation
        
        error_vector = (bitStream ~= bitsDemapped);
        N_errors = sum(error_vector);
        
        BER_fixed_point = N_errors / numBits*100;
        BER_fixed_matrix(int_bit+1,frac_bit+1) = BER_fixed_point;
        
        disp('************ Check BER Fixed ************')
        disp(['(Fixed) Error Bits: ', num2str(N_errors)]);
        disp(['(Fixed) Bit Error Rate (BER):', num2str(BER_fixed_matrix(int_bit+1,frac_bit+1))]);
        end
    end
    
    %%%%%%%%%%%%%%%%%%%% FIXED POINT SIMULATION END %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    if(BER_fixed_point>40)
        test_correlation_fixed = test_correlation_fixed+1;
    end
    
    if(BER_Floating>40)
        test_correlation_foating = test_correlation_foating+1;
    end
    
    disp('************ Check BER Floating ************')
    disp(['(Floating) Error Bits: ', num2str(N_errors_floating)]);
    disp(['(Floating) Bit Error Rate (BER):', num2str(BER_Floating)]);
end

disp('************ Check Correlation ************')
disp(['(Floating) Correalation Error Rate: ', num2str(test_correlation_foating)]);
disp(['(Fixed) Correalation Error Rate: ', num2str(test_correlation_fixed)]);

%% Write QAM data

QAM_filein_real= fopen('./data/QAM_filein_real.txt', 'w');
QAM_filein_imaginary= fopen('./data/QAM_filein_imaginary.txt', 'w');
QAM_answer = fopen('./data/QAM_answer.txt', 'w');

if QAM_filein_real == -1
    error('Cannot open the file: %s', 'QAM_filein_real.txt');
end

if QAM_filein_imaginary == -1
    error('Cannot open the file: %s', 'QAM_filein_imaginary.txt');
end

if QAM_answer == -1
    error('Cannot open the file: %s', 'QAM_answer.txt');
end
TranFFTSymbols= FFTSymbols.';
SymbolsSerial = TranFFTSymbols(:);
for i=1:numBits/4 
    data_quantized_real = float2twoscomp(SymbolsSerial(i), int_bit, frac_bit);
    fprintf(QAM_filein_real, '%x\n', real(data_quantized_real));
    fprintf(QAM_filein_imaginary, '%x\n', imag(data_quantized_real));
end
fprintf(QAM_answer, '%x\n', bitsDemapped);

fclose(QAM_filein_real);
fclose(QAM_filein_imaginary);
fclose(QAM_answer);

%% Write FFT data

FFT_filein_real= fopen('./data/FFT_filein_real.txt', 'w');
FFT_filein_imaginary= fopen('./data/FFT_filein_imaginary.txt', 'w');
FFT_answer_real = fopen('./data/FFT_answer_real.txt', 'w');
FFT_answer_imaginary = fopen('./data/FFT_answer_imaginary.txt', 'w');

if FFT_filein_real == -1
    error('Cannot open the file: %s', 'FFT_filein_real.txt');
end

if FFT_filein_imaginary == -1
    error('Cannot open the file: %s', 'FFT_filein_imaginary.txt');
end

if FFT_answer_real == -1
    error('Cannot open the file: %s', 'FFT_answer_real.txt');
end

if FFT_answer_imaginary == -1
    error('Cannot open the file: %s', 'FFT_answer_imaginary.txt');
end

for i=1:numBits/4 
    data_quantized_real = fi(real(SymbolsSerial(i)), 1, int_bit+frac_bit, frac_bit);
    data_quantized_imaginary = fi(imag(SymbolsSerial(i)), 1, int_bit+frac_bit, frac_bit);
    fprintf(FFT_answer_real, '%s\n', data_quantized_real.hex);
    fprintf(FFT_answer_imaginary, '%s\n', data_quantized_imaginary.hex);
end

TranOFDMsymbol= OFDMsymbol.';
SymbolsSerial = OFDMsymbol(:);

for i=1:numBits/4 
    data_quantized_real = fi(real(SymbolsSerial(i)), 1, int_bit+frac_bit, frac_bit);
    data_quantized_imaginary = fi(imag(SymbolsSerial(i)), 1, int_bit+frac_bit, frac_bit);
    fprintf(FFT_filein_real, '%s\n', data_quantized_real.hex);
    fprintf(FFT_filein_imaginary, '%s\n', data_quantized_imaginary.hex);
end

fclose(FFT_answer_real);
fclose(FFT_answer_imaginary);
fclose(FFT_filein_real);
fclose(FFT_filein_imaginary);

%% Write SYNC data

SYNC_answer= fopen('./data/SYNC_answer.txt', 'w');

if SYNC_answer == -1
    error('Cannot open the file: %s', 'SYNC_answer.txt');
end

for i=1:numBits/4 
    fprintf(SYNC_answer, '%x\n', FFTstartIndexPreamble);
end

fclose(SYNC_answer);
%% Plot %%
plot_inverval = TEST_INVERVAL;

% Plot Fixed Point (only works when intbits and fracbits set TestInterval)
figure(3)
pcolor(TEST_INVERVAL, TEST_INVERVAL,BER_fixed_matrix)
%shading interp
set(gca, 'FontName', 'Times New Roman', 'FontSize', 14)
xlabel('Fraction Bits')
ylabel('Integer Bits')
title(['Receiver Fixed Point Sim.  (SNR = ', num2str(SNR_dB), ' dB)']);
alpha(0.75) 
hClbr2 = colorbar;
set(hClbr2, 'FontName', 'Times New Roman', 'FontSize', 14)
ylabel(hClbr2, 'BER')
clim([0 50]);

figure(4)
x = 0:3:16;

BER_QPSK_fixed = [52.24,8.15,2.49,0.31,0.0074,9.5367e-05];
BER_QPSK = [50.49,7.87,2.31,0.24,0.0024,1e-06];

BER_16QAM_fixed = [49.15,20.88,14.26,8.36,3.29,0.83];
BER_16QAM = [49.54,21.00,13.99,7.89,2.72,0.44];

BER_QPSK = 10*log10(BER_QPSK);
BER_QPSK_fixed = 10*log10(BER_QPSK_fixed);
BER_16QAM = 10*log10(BER_16QAM);
BER_16QAM_fixed = 10*log10(BER_16QAM_fixed);
plot(x,BER_16QAM,'-o',x,BER_16QAM_fixed,'--o',x,BER_QPSK,'-*',x,BER_QPSK_fixed,'--*')

set(gca, 'FontSize', 16);
xlabel('SNR (dB)', 'FontSize', 16);
ylabel('10logBER (dB)', 'FontSize', 16);
title('BER Comparision')
legend('16-QAM','16-QAM Fixed','QPSK','QPSK Fixed')

figure(5)
x = 0:3:15;

BER_QPSK_fixed = [16.05,8.02,2.50,0.31,0.0074,9.5367e-05];
BER_QPSK = [16.19,7.87,2.29,0.24,0.0024,1e-06];

BER_16QAM_fixed = [28.09,20.88,14.26,8.36,3.29,0.83];
BER_16QAM = [27.89,21.00,13.99,7.89,2.72,0.44];

BER_QPSK = 10*log10(BER_QPSK);
BER_QPSK_fixed = 10*log10(BER_QPSK_fixed);
BER_16QAM = 10*log10(BER_16QAM);
BER_16QAM_fixed = 10*log10(BER_16QAM_fixed);
plot(x,BER_16QAM,'-o',x,BER_16QAM_fixed,'--o',x,BER_QPSK,'-*',x,BER_QPSK_fixed,'--*')

set(gca, 'FontSize', 16);
xlabel('SNR (dB)', 'FontSize', 16);
ylabel('10logBER (dB)', 'FontSize', 16);
title('BER Comparision')
legend('16-QAM','16-QAM Fixed','QPSK','QPSK Fixed')

% Plot Correaltion
figure(6)

Coreelation_Error_Rate_Floating = [40,6,0,0,0,0];
Coreelation_Error_Rate_Fixed_15_4 = [51,9,0,0,0,0];
Coreelation_Error_Rate_Fixed_15_3 = [68,21,0,0,0,0];
Coreelation_Error_Rate_Fixed_15_2 = [86,43,10,0,0,0];
Coreelation_Error_Rate_Fixed_15_1 = [95,84,51,19,8,2];
plot(x,Coreelation_Error_Rate_Floating,'-o', ...
    x,Coreelation_Error_Rate_Fixed_15_4,'-*', ...
    x,Coreelation_Error_Rate_Fixed_15_3,'-^', ...
    x,Coreelation_Error_Rate_Fixed_15_2,'-+', ...
    x,Coreelation_Error_Rate_Fixed_15_1,'-x')

set(gca, 'FontSize', 16);
xlabel('SNR (dB)', 'FontSize', 16);
ylabel('Error Rate (%)', 'FontSize', 16);
title('Correlation Error Rate (int:15)')
legend('Floating',' frac:4',' frac:3',' frac:2',' frac:1')

figure(7)

Coreelation_Error_Rate_Floating = [40,3,0,0,0,0];
Coreelation_Error_Rate_Fixed_10_10 = [53,12,1,1,1,1];
Coreelation_Error_Rate_Fixed_11_10 = [53,7,1,1,1,1];
Coreelation_Error_Rate_Fixed_12_10 = [53,5,0,0,0,0];
plot(x,Coreelation_Error_Rate_Floating,'-o', ...
    x,Coreelation_Error_Rate_Fixed_10_10,'-*', ...
    x,Coreelation_Error_Rate_Fixed_11_10,'-^', ...
    x,Coreelation_Error_Rate_Fixed_12_10,'-+')

set(gca, 'FontSize', 16);
xlabel('SNR (dB)', 'FontSize', 16);
ylabel('Error Rate (%)', 'FontSize', 16);
title('Correlation Error Rate (frac:10)')
legend('Floating',' int:10',' int:11',' int:12')

figure(8)

Coreelation_Error_Rate_Floating = [40,3,0,0,0,0];
Coreelation_Error_Rate_Fixed_12_4 = [53,5,0,0,0,0];
plot(x,Coreelation_Error_Rate_Floating,'-o', ...
    x,Coreelation_Error_Rate_Fixed_12_4,'-*')

set(gca, 'FontSize', 16);
xlabel('SNR (dB)', 'FontSize', 16);
ylabel('Error Rate (%)', 'FontSize', 16);
title('Correlation Error Rate')
legend('Floating',' int:12 frac:4')
