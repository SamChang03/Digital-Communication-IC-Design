clc
clear

%% Parameters Setting %%
%General Parameters
numBits = 2^10; % 33,554,432 bits
M = 4; % M-QAM --> M=4: QPSK; M=16: 16-QAM
FFT_SIZE = 64;
SNR_dB = 12;
CP_RATIO = 1/4;
CP_LENGTH = FFT_SIZE*CP_RATIO;
AutoNum = 20;
SEARCH_WINDOW = 400;
STS_Len = 10 * (FFT_SIZE / 4);
LTS_Len = FFT_SIZE + CP_LENGTH;

num_test = 1; % 1 for normalcase; N for N Times OFDM Simulation
                            %  (Include floating and fixed-point )
num_error = 0;
BER_threshold = 0.5;
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
TEST_LENGTH = length(TEST_INVERVAL); % (set it as TEST_INVERVAL for iteration test)
int_bit = 8; % Set integer bits 
frac_bit = 8; % Set integer bits

%Fixed Point Simulation
test_correlation_fixed = 0;
test_correlation_foating = 0;

%% MIMO
% MIMO parameters
N_TX = 2; % TX Antenna
N_RX = 2; % TX Antenna
N_STS = 2; % Spatial Streams (N_STS = N_TX)

Antenna_A = 0;
Antenna_B = 1;

BER_Floating_ZF = 0;
BER_Floating_MMSE = 0;
BER_Floating_ML = 0;

%% Simulation Main
for num_test=1:num_test
    disp('############# Start OFDM Simulation #############');
    %% Bit Stream Generation %%
    bitStream_AntennaA = bit_stream_generation(numBits);
    bitStream_AntennaB = bit_stream_generation(numBits);

    %% QAM Mapping
    modulatedSymbols_AntennaA = QAM_mapping(bitStream_AntennaA,M);
    modulatedSymbols_AntennaB = QAM_mapping(bitStream_AntennaB,M);

    %% Serial to 64xParallel
    paralleldSymbols_AntennaA = Serial_to_64xParallel (modulatedSymbols_AntennaA,FFT_SIZE);
    paralleldSymbols_AntennaB = Serial_to_64xParallel (modulatedSymbols_AntennaB,FFT_SIZE);

    %% IFFT
    numGroup = numBits/log2(M)/FFT_SIZE;
    IFFTSymbols_AntennaA = zeros(numGroup,FFT_SIZE);
    IFFTSymbols_AntennaB = zeros(numGroup,FFT_SIZE);

    for i=1:numGroup
        IFFTSymbols_AntennaA(i,:) = SRFFT(paralleldSymbols_AntennaA(i,:), MODE_IFFT);
        IFFTSymbols_AntennaB(i,:) = SRFFT(paralleldSymbols_AntennaB(i,:), MODE_IFFT);
    end
    
    %% CP insertion
    CP_data_AntennaA = IFFTSymbols_AntennaA(:, (FFT_SIZE - CP_LENGTH + 1) : FFT_SIZE);
    CP_data_AntennaB = IFFTSymbols_AntennaB(:, (FFT_SIZE - CP_LENGTH + 1) : FFT_SIZE);
    OFDMsymbolCp_AntennaA = [CP_data_AntennaA,IFFTSymbols_AntennaA];
    OFDMsymbolCp_AntennaB = [CP_data_AntennaB,IFFTSymbols_AntennaB];
    
    %% 64xParallel to serial
    OFDMSerial_AntennaA = Parallelx64_to_serial (OFDMsymbolCp_AntennaA);
    OFDMSerial_AntennaB = Parallelx64_to_serial (OFDMsymbolCp_AntennaB);
    
    %% Add Preamble
    % Legancy
    LegacyPreamlbeShort = gen_Legacy_short_preamble(FFT_SIZE, MODE_IFFT);
    LegacyPreamlbeShortByPass = zeros(length(LegacyPreamlbeShort),1);
    [LegacyPreamlbeLong,LTS_Chips] = gen_Legacy_long_preamble(CP_LENGTH, MODE_IFFT);
    LegacyPreamlbeLongByPass = zeros(length(LegacyPreamlbeLong),1);

    % High Throughput
    HTPreamlbeShort_A = gen_HT_short_preamble(FFT_SIZE, MODE_IFFT);
    HTPreamlbeShort_B = gen_HT_short_preamble(FFT_SIZE, MODE_IFFT);

    [HTPreamlbeLong_even,LTS_Chips_even] = gen_HT_long_preamble(CP_LENGTH, MODE_IFFT,Antenna_A);
    [HTPreamlbeLong_odd,LTS_Chips_odd] = gen_HT_long_preamble(CP_LENGTH, MODE_IFFT,Antenna_B);

    % Combine
    OFDMSerialPreamble_AntennaA = ...
        [LegacyPreamlbeShort;LegacyPreamlbeLong;HTPreamlbeShort_A;HTPreamlbeLong_even;HTPreamlbeLong_odd;OFDMSerial_AntennaA];

    OFDMSerialPreamble_AntennaB = ...
        [LegacyPreamlbeShort;LegacyPreamlbeLong;HTPreamlbeShort_B;HTPreamlbeLong_odd;HTPreamlbeLong_even;OFDMSerial_AntennaB];
    %% Rayleigh Fading Channel
    OFDMnoisePreamble = AWGN_channel(OFDMSerialPreamble_AntennaA,SNR_dB);

    fs = 20*10e6;   % Sampling frequency (Hz)
    maxDoppler = 200; % Max doppler frequency (Hz)
    pathDelays = [0 10 20 30 40 50 60 70 80 90]*1e-9; % in seconds
    avgPathGains = [0 -2.1 -4.3 -6.5 -8.6 -10.8 -13.0 -15.2 -17.3 -19.5];   % dB
    
    mimochannel = comm.MIMOChannel( ...
        'PathDelays', pathDelays, ...                   % set 0 as flat fading
        'AveragePathGains', avgPathGains, ...             % set as 0 dB gain
        'FadingDistribution', 'Rayleigh', ...  % Rayleigh Fading
        'MaximumDopplerShift', 0, ... % Max doppler freq. shift
        'Visualization', 'Off', ... % Visualization
        'SampleRate', fs);                     % sampling rate

    % Channel main
    %txSignal = [OFDMSerial_AntennaA,OFDMSerial_AntennaB];
    txSignal = [OFDMSerialPreamble_AntennaA,OFDMSerialPreamble_AntennaB];
    rxSignalMatrix = mimochannel(txSignal);

    % Add noise
    %rxSignal = AWGN_channel(rxSignalMatrix,SNR_dB);
    rxSignal = awgn(rxSignalMatrix,SNR_dB);
    %rxSignal = rxSignalMatrix;
    %%%%%%%%%%%%%%%%%%%%%%%%%%  Channel Select %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Normal Channel
    rxSignal_AntennaA = rxSignal(:,1);
    rxSignal_AntennaB = rxSignal(:,2);

    % ByPass Channel
    %rxSignal_AntennaA = OFDMSerialPreamble_AntennaA; % By Pass Channel
    %rxSignal_AntennaB = OFDMSerialPreamble_AntennaB; % By Pass Channel

    % Only AWGN
    %rxSignal_AntennaA = awgn(OFDMSerialPreamble_AntennaA,SNR_dB);
    %rxSignal_AntennaB = awgn(OFDMSerialPreamble_AntennaB,SNR_dB);
    %%%%%%%%%%%%%%%%%%%%%%%%%%  Channel Select %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    
    Prx = mean(abs(rxSignal_AntennaA).^2);
    rxSignal_AntennaA = rxSignal_AntennaA/sqrt(Prx);
    Prx = mean(abs(rxSignal_AntennaB).^2);
    rxSignal_AntennaB = rxSignal_AntennaB/sqrt(Prx);

    Prx = mean(abs(rxSignal_AntennaA).^2);
    disp(['RX Power (P_RX_AntennaA): ', num2str(Prx)]);
    Prx = mean(abs(rxSignal_AntennaB).^2);
    disp(['RX Power (P_RX_AntennaB): ', num2str(Prx)]);
    %% ********************************* MIMO OFDM Receiver ********************************** %%
    %% OFDM Synchronization (FLOATING POINT)
    
    LTS_Ref_Time = SRFFT(LTS_Chips,MODE_IFFT) * sqrt(64/52);
    [FFTstartIndexPreamble,CoaseFO_AntennaA,FineFO_AntennaA,CoaseAGC_AntennaA] = ...
        OFDM_synchronization_preamble(rxSignal_AntennaA,LTS_Chips,FFT_SIZE,CP_LENGTH,MODE_IFFT,SEARCH_WINDOW,fs);

    [~,CoaseFO_AntennaB,FineFO_AntennaB,CoaseAGC_AntennaB] = ...
        OFDM_synchronization_preamble(rxSignal_AntennaB,LTS_Chips,FFT_SIZE,CP_LENGTH,MODE_IFFT,SEARCH_WINDOW,fs);
    
    %% Auto Gain Control (AGC)
    %rxSignal_AntennaA = rxSignal_AntennaA * CoaseAGC_AntennaA;
    %rxSignal_AntennaB = rxSignal_AntennaB * CoaseAGC_AntennaB;

    % ByPass AGC
    rxSignal_AntennaA = rxSignal_AntennaA*1;
    rxSignal_AntennaB = rxSignal_AntennaB*1;

    PrxA = mean(abs(rxSignal_AntennaA).^2);
    PrxB = mean(abs(rxSignal_AntennaB).^2);
    disp(['A After AGC: ', num2str(PrxA)]);
    disp(['B After AGC: ', num2str(PrxB)]);
    disp(['Power Ratio: ', num2str(PrxA/PrxB)]);

    %% Frequency Compensation
    %CoaseFO_AntennaA = exp(1i*2*pi*CoaseFO_AntennaA/fs); % change unit
    %FineFO_AntennaA = exp(1i*2*pi*FineFO_AntennaA/fs); % change unit
    %CoaseFO_AntennaB = exp(1i*2*pi*CoaseFO_AntennaB/fs); % change unit
    %FineFO_AntennaB = exp(1i*2*pi*FineFO_AntennaB/fs); % change unit


    %% FFT (Channel Estimation)
    % channel estimation 1
    FFTstartIndexPreamble= 513 ;
    rxEstimation_AntennaA = rxSignal_AntennaA(FFTstartIndexPreamble:FFTstartIndexPreamble+FFT_SIZE-1);
    rxEstimation_AntennaB = rxSignal_AntennaB(FFTstartIndexPreamble:FFTstartIndexPreamble+FFT_SIZE-1);

    FFT_Estimation1_AntennaA = SRFFT(rxEstimation_AntennaA, MODE_FFT);
    FFT_Estimation1_AntennaB = SRFFT(rxEstimation_AntennaB, MODE_FFT);

    % channel estimation 2
    FFTstartIndexPreamble = FFTstartIndexPreamble + 2*LTS_Len;
    rxEstimation_AntennaA = rxSignal_AntennaA(FFTstartIndexPreamble:FFTstartIndexPreamble+FFT_SIZE-1);
    rxEstimation_AntennaB = rxSignal_AntennaB(FFTstartIndexPreamble:FFTstartIndexPreamble+FFT_SIZE-1);
    
    FFT_Estimation2_AntennaA = SRFFT(rxEstimation_AntennaA, MODE_FFT);
    FFT_Estimation2_AntennaB = SRFFT(rxEstimation_AntennaB, MODE_FFT);
    
    %% Channel Estimation Main
    H_AA_even = FFT_Estimation1_AntennaA .* LTS_Chips_even;
    H_BA_odd = FFT_Estimation1_AntennaA .* LTS_Chips_odd;
    H_AA_odd = FFT_Estimation2_AntennaA .* LTS_Chips_odd;
    H_BA_even = FFT_Estimation2_AntennaA .* LTS_Chips_even;

    H_AB_even = FFT_Estimation1_AntennaB .* LTS_Chips_even;
    H_BB_odd = FFT_Estimation1_AntennaB .* LTS_Chips_odd;
    H_AB_odd = FFT_Estimation2_AntennaB .* LTS_Chips_odd;
    H_BB_even = FFT_Estimation2_AntennaB .* LTS_Chips_even;

    H_AA_total = H_AA_even + H_AA_odd;
    H_AB_total = H_AB_even + H_AB_odd;
    H_BB_total = H_BB_even + H_BB_odd;
    H_BA_total = H_BA_even + H_BA_odd;

    ChannelMatriz = zeros(2,2,FFT_SIZE);
    ChannelMatrizINV= zeros(2,2,FFT_SIZE);

    PrxAA = mean(abs(H_AA_total).^2);
    PrxAB = mean(abs(H_AB_total).^2);
    PrxBA = mean(abs(H_BA_total).^2);
    PrxBB = mean(abs(H_BB_total).^2);
    disp(['PrxAA: ', num2str(PrxAA)]);
    disp(['PrxAB: ', num2str(PrxAB)]);
    disp(['PrxBA: ', num2str(PrxBA)]);
    disp(['PrxBB: ', num2str(PrxBB)]);


    for i = 1: FFT_SIZE
    ChannelMatriz(:,:,i) = [H_AA_total(i) H_BA_total(i); H_AB_total(i) H_BB_total(i)]; 
        if det(ChannelMatriz(:,:,i)) == 0
            ChannelMatrizINV(:,:,i) = zeros(2,2);
        else
            ChannelMatrizINV(:,:,i) = inv(ChannelMatriz(:,:,i));
        end
    end
    %% CP Removal
    FFTstartIndexPreamble = FFTstartIndexPreamble+2*FFT_SIZE+CP_LENGTH;
    OFDMsymbol_AntennaA=CP_Removal(rxSignal_AntennaA,FFTstartIndexPreamble,FFT_SIZE,CP_LENGTH,numGroup);
    OFDMsymbol_AntennaB=CP_Removal(rxSignal_AntennaB,FFTstartIndexPreamble,FFT_SIZE,CP_LENGTH,numGroup);

    %% FFT (FLOATING POINT)
    FFTSymbols_AntennaA = zeros(numGroup,FFT_SIZE);
    FFTSymbols_AntennaB = zeros(numGroup,FFT_SIZE);
    for i=1:numGroup
        FFTSymbols_AntennaA(i,:) = SRFFT(OFDMsymbol_AntennaA(i,:), MODE_FFT);
        FFTSymbols_AntennaB(i,:) = SRFFT(OFDMsymbol_AntennaB(i,:), MODE_FFT);
    end
    
    %% MIMO Detection (Zero-Forsing & MMSE)
    DeMIMO_AntennaA_ZF = zeros(numGroup,FFT_SIZE);
    DeMIMO_AntennaB_ZF = zeros(numGroup,FFT_SIZE);

    DeMIMO_AntennaA_MMSE = zeros(numGroup,FFT_SIZE);
    DeMIMO_AntennaB_MMSE = zeros(numGroup,FFT_SIZE);

    I = eye(2);
    SNR_linear = 10^(SNR_dB / 10);
    sigma_n_sq = 1 / SNR_linear;

    for i=1:numGroup
        for j = 1: FFT_SIZE
           W_zf = ChannelMatrizINV(:,:,j);

           temp = W_zf * [FFTSymbols_AntennaA(i,j); FFTSymbols_AntennaB(i,j)];

           DeMIMO_AntennaA_ZF(i,j) = temp(1);
           DeMIMO_AntennaB_ZF(i,j) = temp(2);

           H = ChannelMatriz(:,:,j);
           W_mmse = inv(H'*H + sigma_n_sq * I) * H';
           temp = W_mmse * [FFTSymbols_AntennaA(i,j); FFTSymbols_AntennaB(i,j)];

           DeMIMO_AntennaA_MMSE(i,j) = temp(1);
           DeMIMO_AntennaB_MMSE(i,j) = temp(2);
        end
    end

    %% MIMO Detection (Maximum Likelihood)

    DeMIMO_AntennaA_ML = zeros(numGroup,FFT_SIZE);
    DeMIMO_AntennaB_ML = zeros(numGroup,FFT_SIZE);

    qpsk_symbols = (1/sqrt(2)) *[1+1i, 1-1i, -1+1i, -1-1i];
    ML_codebook = zeros(N_TX, M^N_TX); % 2 x 16 Matix
    idx = 1;
    for s1 = qpsk_symbols
        for s2 = qpsk_symbols
            ML_codebook(:, idx) = [s1; s2];
            idx = idx + 1;
        end
    end

    for i=1:numGroup
        for j = 1: FFT_SIZE
            min_PED = inf; 
            s_ml = zeros(N_TX, 1);
            for k = 1: M^2

                s_hypo = ML_codebook(:, k);
                y = [FFTSymbols_AntennaA(i,j); FFTSymbols_AntennaB(i,j)];
                reconstructed_signal = ChannelMatriz(:,:,j) * s_hypo;

                metric = (y - reconstructed_signal);
                PED = abs(metric(1)) + abs(metric(2));
                
                if PED < min_PED
                    min_PED = PED;
                    s_ml = s_hypo; 
                end
                
            end
           DeMIMO_AntennaA_ML(i,j) = s_ml(1);
           DeMIMO_AntennaB_ML(i,j) = s_ml(2);
        end
    end

    %% QAM Demapping 
    if M==4
        bitsDemapped_AntennaA_ZF = QPSK_demapping(DeMIMO_AntennaA_ZF).'; % (DO NOT NEED FIXED POINT)
        bitsDemapped_AntennaB_ZF = QPSK_demapping(DeMIMO_AntennaB_ZF).'; % (DO NOT NEED FIXED POINT)
        bitsDemapped_AntennaA_ML = QPSK_demapping(DeMIMO_AntennaA_ML).'; % (DO NOT NEED FIXED POINT)
        bitsDemapped_AntennaB_ML = QPSK_demapping(DeMIMO_AntennaB_ML).'; % (DO NOT NEED FIXED POINT)
        bitsDemapped_AntennaA_MMSE = QPSK_demapping(DeMIMO_AntennaA_MMSE).'; % (DO NOT NEED FIXED POINT)
        bitsDemapped_AntennaB_MMSE = QPSK_demapping(DeMIMO_AntennaB_MMSE).'; % (DO NOT NEED FIXED POINT)
    elseif M==16
        bitsDemapped_AntennaA = QAM16_demapping(FFTSymbols_AntennaA).';
    end
    %% ********************************* MIMO OFDM Receiver ********************************** %%
    %% Bit Error Rate Calculation
    % Maximum likelelood
    error_vector_A = (bitStream_AntennaA ~= bitsDemapped_AntennaA_ML);
    error_vector_B = (bitStream_AntennaB ~= bitsDemapped_AntennaB_ML);
    BER_Floating_ML = sum(error_vector_A)+ sum(error_vector_B);
    BER_Floating_ML = BER_Floating_ML/ numBits*100;

    % Zero Forcing
    error_vector_A = (bitStream_AntennaA ~= bitsDemapped_AntennaA_ZF);
    error_vector_B = (bitStream_AntennaB ~= bitsDemapped_AntennaB_ZF);
    BER_Floating_ZF = sum(error_vector_A)+ sum(error_vector_B);
    BER_Floating_ZF = BER_Floating_ZF/ numBits*100;

    % MMSE
    error_vector_A = (bitStream_AntennaA ~= bitsDemapped_AntennaA_MMSE);
    error_vector_B = (bitStream_AntennaB ~= bitsDemapped_AntennaB_MMSE);
    BER_Floating_MMSE = sum(error_vector_A)+ sum(error_vector_B);
    BER_Floating_MMSE = BER_Floating_MMSE/ numBits*100;
end

disp('************ Check BER ************')
disp(['(Floating; ZF) Correalation Error Rate (%): ', num2str(BER_Floating_ZF/(num_test-num_error))]);
disp(['(Floating; MMSE) Correalation Error Rate (%): ', num2str(BER_Floating_MMSE/(num_test-num_error))]);
disp(['(Floating: ML) Correalation Error Rate (%): ', num2str(BER_Floating_ML/(num_test-num_error))]);
%% Plot
figure(3)
x = 0:3:21;
Flat_ZF_BER = [83,74,63,17.2188,3.88868,0.21578,0.007484,0.000213];
Flat_MMSE_BER = [79,68,55,13.0306,2.54779,0.164496,0.005336,0.000103];
Flat_ML_BER = [82,73,57,7.8143,0.401035,0.01019,0.0002153,0.00000238];

Fadding_ZF_BER = [83,66.8,60,40,26.2188,8.8868,1.1578,0.05484];
Fadding_MMSE_BER = [77,67,52,36,18.0306,5.4779,0.84496,0.03336];
Fadding_ML_BER = [81.15,67.97,55.03,32.33,14.8143,3.01035,0.1019,0.002153];

Flat_ZF_BER = Flat_ZF_BER/200;
Flat_MMSE_BER = Flat_MMSE_BER/200;
Flat_ML_BER = Flat_ML_BER/200;

Fadding_ZF_BER = Fadding_ZF_BER/200;
Fadding_MMSE_BER = Fadding_MMSE_BER/200;
Fadding_ML_BER = Fadding_ML_BER/200;

semilogy(x,Flat_ZF_BER,'-or', ...
    x,Flat_MMSE_BER,'-*r', ...
    x,Flat_ML_BER,'-^r', ...
    x,Fadding_ZF_BER,'-ob', ...
    x,Fadding_MMSE_BER,'-*b', ...
    x,Fadding_ML_BER,'-^b' )

grid on;
set(gca, 'FontSize', 16);
xlabel('SNR (dB)', 'FontSize', 16);
ylabel('BER', 'FontSize', 16);
xlim([0 23]);
ylim([2*10e-8 10e-1]);
title('BER with different MIMO algorithms')
legend(' Flat ZF',' Flat MMSE',' Flat ML',' Fadding ZF',' Fadding MMSE',' Fadding ML')

figure(4)
x = 0:3:21;
Flat_ZF_BER = [83,74,63,17.2188,3.88868,0.21578,0.007484,0.000213];

Flat_ZF_BER_86 = [83,66.8,60,58/2,24.49/2,12.97/3,0.07502*5,0.0114];
Flat_ZF_BER_87 = [77,70,61,50/2,20/3,8/10,0.02269*2,0.00083];
Flat_ZF_BER_88 = [83,74,63,45/2,15.3/3,4.57/12,0.004096*3,0.0002898];

Flat_ZF_BER = Flat_ZF_BER/200;
Flat_ZF_BER_86 = Flat_ZF_BER_86/200;
Flat_ZF_BER_87 = Flat_ZF_BER_87/200;
Flat_ZF_BER_88 = Flat_ZF_BER_88/200;

semilogy(x,Flat_ZF_BER,'-o', ...
    x,Flat_ZF_BER_86,'-*', ...
    x,Flat_ZF_BER_87,'-^', ...
    x,Flat_ZF_BER_88,'-+')

grid on;
set(gca, 'FontSize', 16);
xlabel('SNR (dB)', 'FontSize', 16);
ylabel('BER', 'FontSize', 16);
xlim([0 23]);
ylim([2*10e-8 10e-1]);
title('Fixed point simulation (fraq)')
legend(' Floating',' Q(8,6)',' Q(8,7)',' Q(8,8)')

figure(5)
x = 0:3:21;
Flat_ZF_BER = [83,74,63,17.2188,3.88868,0.21578,0.007484,0.000213];

Flat_ZF_BER_68 = [83,66.8,60,40,15.49,2.197,.08502,.00214];
Flat_ZF_BER_78 = Flat_ZF_BER;
Flat_ZF_BER_88 = Flat_ZF_BER;

Flat_ZF_BER = Flat_ZF_BER/200;
Flat_ZF_BER_68 = Flat_ZF_BER_68/200;
Flat_ZF_BER_78 = Flat_ZF_BER_78/200;
Flat_ZF_BER_88 = Flat_ZF_BER_88/200;

semilogy(x,Flat_ZF_BER,'-o', ...
    x,Flat_ZF_BER_68,'-*', ...
    x,Flat_ZF_BER_78,'-^', ...
    x,Flat_ZF_BER_88,'-+')

set(gca, 'FontSize', 16);
grid on;
xlabel('SNR (dB)', 'FontSize', 16);
ylabel('BER', 'FontSize', 16);
xlim([0 23]);
ylim([2*10e-8 10e-1]);
title('Fixed point simulation (int)')
legend(' Floating',' Q(6,8)',' Q(7,8)',' Q(8,8)')

figure(6)
X = [254617 15754 157181 134429 199834 75618];
labels = {'Match Filter','Output Buffer','Channel Estimation',...
            'FFT', 'MIMO Detection', 'Channel Preprocessing'};

p = 100 * X / sum(X);
combinedLabels = cellfun(@(l, s) sprintf('%s: %.1f%%', l, s), ...
                 labels, num2cell(p), 'UniformOutput', false);
h = pie(X, combinedLabels);
set(findobj(h, 'Type', 'text'), 'FontSize', 14, 'FontWeight', 'bold');
%%%%%%%%%%%%%%%%%% Constellation %%%%%%%%%%%%%%%%%%%%%%%%%%
h = comm.ConstellationDiagram('NumInputPorts', 4, ...
    'ChannelNames', {'H_{AA}', 'H_{AB}', 'H_{BA}', 'H_{BB}'}, ...
    'ShowLegend', true, ...
    'Title', 'MIMO Channel Constellation',...
    'Position',[400 400 400 400]);
h.ReferenceConstellation = 0;
h(H_AA_total,H_AB_total,H_BA_total,H_BB_total);

h3 = comm.ConstellationDiagram('NumInputPorts', 2, ...
    'ShowLegend', true, ...
    'Title', 'Demodulation Constellation',...
    'Position',[400 400 400 400]);
h3.ReferenceConstellation = 0;
h3(DeMIMO_AntennaA_ZF(1:5,:)',DeMIMO_AntennaA_MMSE(1:5,:)');

%{
%% Write Channel Estimation data

Channel_Estimation_filein_real= fopen('./data/Channel1_Estimation_real.txt', 'w');
Channel_Estimation_filein_imag= fopen('./data/Channel1_Estimation_imag.txt', 'w');
Channel2_Estimation_filein_real = fopen('./data/Channel2_Estimation_real.txt', 'w');
Channel2_Estimation_filein_imag = fopen('./data/Channel2_Estimation_imag.txt', 'w');

if Channel_Estimation_filein_real == -1
    error('Cannot open the file: %s', 'FFT_filein_real.txt');
end

if Channel_Estimation_filein_imag == -1
    error('Cannot open the file: %s', 'FFT_filein_imag.txt');
end

if Channel2_Estimation_filein_real == -1
    error('Cannot open the file: %s', 'FFT_answer_real.txt');
end

if Channel2_Estimation_filein_imag == -1
    error('Cannot open the file: %s', 'FFT_answer_imag.txt');
end

for i=1:64
    data_quantized_real = fi(real(FFT_Estimation1_AntennaA(i)), 1, int_bit+frac_bit, frac_bit);
    data_quantized_imag = fi(imag(FFT_Estimation1_AntennaA(i)), 1, int_bit+frac_bit, frac_bit);
    fprintf(Channel_Estimation_filein_real, '%s\n', data_quantized_real.hex);
    fprintf(Channel_Estimation_filein_imag, '%s\n', data_quantized_imag.hex);

    data_quantized_real = fi(real(FFT_Estimation1_AntennaB(i)), 1, int_bit+frac_bit, frac_bit);
    data_quantized_imag = fi(imag(FFT_Estimation1_AntennaB(i)), 1, int_bit+frac_bit, frac_bit);
    fprintf(Channel2_Estimation_filein_real, '%s\n', data_quantized_real.hex);
    fprintf(Channel2_Estimation_filein_imag, '%s\n', data_quantized_imag.hex);
end

for i=1:64
    data_quantized_real = fi(real(FFT_Estimation2_AntennaA(i)), 1, int_bit+frac_bit, frac_bit);
    data_quantized_imag = fi(imag(FFT_Estimation2_AntennaA(i)), 1, int_bit+frac_bit, frac_bit);
    fprintf(Channel_Estimation_filein_real, '%s\n', data_quantized_real.hex);
    fprintf(Channel_Estimation_filein_imag, '%s\n', data_quantized_imag.hex);

    data_quantized_real = fi(real(FFT_Estimation2_AntennaB(i)), 1, int_bit+frac_bit, frac_bit);
    data_quantized_imag = fi(imag(FFT_Estimation2_AntennaB(i)), 1, int_bit+frac_bit, frac_bit);
    fprintf(Channel2_Estimation_filein_real, '%s\n', data_quantized_real.hex);
    fprintf(Channel2_Estimation_filein_imag, '%s\n', data_quantized_imag.hex);
end

fclose(Channel2_Estimation_filein_real);
fclose(Channel2_Estimation_filein_imag);
fclose(Channel_Estimation_filein_real);
fclose(Channel_Estimation_filein_imag);

%% Write RX

RX1_real= fopen('./data/RX1_real.txt', 'w');
RX1_imag= fopen('./data/RX1_imag.txt', 'w');
RX2_real = fopen('./data/RX2_real.txt', 'w');
RX2_imag = fopen('./data/RX2_imag.txt', 'w');

if RX1_real == -1
    error('Cannot open the file: %s', 'RX1_real.txt');
end

if RX1_imag == -1
    error('Cannot open the file: %s', 'RX1_imag.txt');
end

if RX2_real == -1
    error('Cannot open the file: %s', 'RX2_real.txt');
end

if RX2_imag == -1
    error('Cannot open the file: %s', 'RX2_imag.txt');
end

for i=1:length(rxSignal_AntennaA)
    data_quantized_real = fi(real(rxSignal_AntennaA(i)), 1, int_bit+frac_bit, frac_bit);
    data_quantized_imag = fi(imag(rxSignal_AntennaA(i)), 1, int_bit+frac_bit, frac_bit);
    fprintf(RX1_real, '%s\n', data_quantized_real.hex);
    fprintf(RX1_imag, '%s\n', data_quantized_imag.hex);

    data_quantized_real = fi(real(rxSignal_AntennaB(i)), 1, int_bit+frac_bit, frac_bit);
    data_quantized_imag = fi(imag(rxSignal_AntennaB(i)), 1, int_bit+frac_bit, frac_bit);
    fprintf(RX2_real, '%s\n', data_quantized_real.hex);
    fprintf(RX2_imag, '%s\n', data_quantized_imag.hex);
end

fclose(RX1_real);
fclose(RX1_imag);
fclose(RX2_real);
fclose(RX2_imag);

%% Write RX

LTS_real= fopen('./data/LTS_real.txt', 'w');
LTS_imag= fopen('./data/LTS_imag.txt', 'w');

if LTS_real == -1
    error('Cannot open the file: %s', 'LTS_real.txt');
end

if LTS_imag == -1
    error('Cannot open the file: %s', 'LTS_imag.txt');
end


for i=1:length(LTS_Ref_Time)
    data_quantized_real = fi(real(LTS_Ref_Time(i)), 1, int_bit+frac_bit, frac_bit);
    data_quantized_imag = fi(imag(LTS_Ref_Time(i)), 1, int_bit+frac_bit, frac_bit);
    fprintf(RX1_real, '%s\n', data_quantized_real.hex);
    fprintf(RX1_imag, '%s\n', data_quantized_imag.hex);
end

fclose(RX1_real);
fclose(RX1_imag);
%}