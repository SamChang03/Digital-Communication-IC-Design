function First_Data_Start = OFDM_LTS_synchronization(OFDMnoisePreamble, LTS_Chips, STS_start_index, FFT_SIZE, CP_LENGTH, MODE_IFFT)
% OFDM_LTS_FINE_TIMING performs Fine Timing Synchronization using Cross-Correlation 

%% Parameters
LTS_Sym_Len = FFT_SIZE; % 64 samples (T_LT)
STS_Total_Len = 10 * (FFT_SIZE / 4); % 160 samples (for coarse offset from STS end)
LTS_CP_32 = CP_LENGTH*2; % The fixed CP length for the first LTS symbol (T_G)
LTS_Total_Len = LTS_CP_32 + 2 * LTS_Sym_Len; % 32 + 64 + 64 = 160 samples (Total L-LTF length)

%% --- Generate LTS Reference From Know LTS Chips ---

% Map LTS Chips to the FFT grid
Tx_LTS_Freq = zeros(FFT_SIZE, 1);
SC_INDICES = [-26:-1, 1:26];

Tx_LTS_Freq(mod(SC_INDICES, FFT_SIZE) + 1) = LTS_Chips(1:52);

% IFFT and Power Normalization
LTS_Ref_Time = SRFFT(Tx_LTS_Freq,MODE_IFFT) * sqrt(64/52); 
%% Fine Synchronization (Cross-Correlation)

% Coarse LTS Start from STS result
Coarse_LTS_Start = STS_start_index + STS_Total_Len; 

% Create a search window 
Search_Window = 100; 
Search_Start = Coarse_LTS_Start;

% Main Cross-Correlation
Corr_Length = 2*Search_Window - LTS_Sym_Len;
XCorr_Result = zeros(Corr_Length, 1);
Power = zeros(Corr_Length, 1);

for n = 1:Corr_Length

    % Window (legnth = LTS_Sym_Len = 64 samples)
    Rx_Segment = OFDMnoisePreamble(Search_Start + n  : (Search_Start + n  + LTS_Sym_Len - 1));

    % Cross-Correlation (Window & Know LTS Chips in time domain)
    XCorr_Result(n) = abs(Rx_Segment.' * conj(LTS_Ref_Time));

    % M(m) - Normalization Power (denominator using the delayed part power)
    Power(n) = sum(abs(LTS_Ref_Time).^2); 
end
normCross = (abs(XCorr_Result).^2) ./ (Power.^2);

%% Find Data Start
THRESHOLD = 0.6;
first_peak = find(normCross > THRESHOLD, 1, 'first');

% Find the peak of the Cross-Correlation
if isempty(first_peak)
    first_peak = 1;
end
XCorr_Peak_Offset = first_peak;
LTS1_FFT_Start_Exact = Search_Start + XCorr_Peak_Offset; 
%  LTS_1 Start Point
LTS_1_Start_point = LTS1_FFT_Start_Exact - LTS_CP_32;

%
First_Data_Start = LTS_1_Start_point + LTS_Total_Len;

%% Plot
figure(2)
plot(normCross);
title('OFDM Fine Synchronization');
%hold on;
xlabel('Sampling Index (m)');
ylabel('Cross-Correlation');

end