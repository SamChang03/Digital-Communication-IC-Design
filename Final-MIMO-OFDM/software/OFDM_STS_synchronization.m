function [STS_start_index,CoaseAGC,CoaseFO] = OFDM_STS_synchronization(OFDMnoisePreamble, FFT_SIZE,SEARCH_WINDOW,fs)
% OFDM STS SYNCHRONIZATION 

% Parameters for STS correlation
STS_PERIOD = FFT_SIZE / 4; % 64 / 4 = 16 samples periodicity
Cor_Len = SEARCH_WINDOW; % Limit search length

Auto = zeros(Cor_Len, 1);
Power = zeros(Cor_Len, 1);

%% Autocorrelation 
for m = 1 : Cor_Len
    
    % r_m is the signal from sample m to m + STS_PERIOD - 1
    r_m = OFDMnoisePreamble(m : m + STS_PERIOD - 1);
    
    % r_{m+16} is the signal delayed by 16 samples
    r_m_plus_delay = OFDMnoisePreamble(m + STS_PERIOD : m + 2*STS_PERIOD - 1);
    
    % P(m) - Autocorrelation (numerator)
    Auto(m) = sum(r_m .* conj(r_m_plus_delay));
    
    % M(m) - Normalization Power (denominator using the delayed part power)
    Power(m) = sum(abs(r_m).^2); 
end

%% Normalization
normAuto = (abs(Auto).^2) ./ (Power.^2);

%% 2. Find the Plateau Start

% Threshold for detection 
THRESHOLD = 0.5; 
[~, locs] = findpeaks(normAuto, 'MinPeakHeight', THRESHOLD, 'MinPeakDistance', 5);

if isempty(locs)
    warning('STS Coarse Synchronization Failed: Could not detect the preamble.');
    STS_start_index = 1;
else
    
    % Find the first sample exceeds the threshold.
    first_hit_index = find(normAuto > THRESHOLD, 1, 'first');
    
    if isempty(first_hit_index)
         first_hit_index = locs(1);
    end
    
    STS_start_index = first_hit_index;
    if STS_start_index < 1
         STS_start_index = 1; % Cannot start before the first sample
    end
end

%% 3. Auto Gain Control (AGC)
Plstf = mean((Power(STS_start_index:STS_start_index+16))/16);
disp(['L-STF Power (P_L-STF): ', num2str(Plstf)]);

% AGC LUT
CoaseAGC = 1;
% compansate loss
if Plstf < 0.25
    CoaseAGC = 2;
elseif Plstf < 0.5
    CoaseAGC = 1.4;
% compansate gain
elseif Plstf > 2
    CoaseAGC = 0.7;
elseif Plstf > 4
    CoaseAGC = 0.5;
end
CoaseAGC = 1;
%% 4. Coase Frequency Offset Estimation
Ts = 1/fs;
phi_rad = angle(sum(Auto(first_hit_index:first_hit_index+16)));
CoaseFO = -phi_rad/(2*pi*16*Ts);
disp(['Coase Frequency Offset: ', num2str(CoaseFO)]);

%% Plot %%
figure(1)
plot(normAuto);
%hold on;
%plot(locs, pks, 'ro', 'MarkerFaceColor', 'r');
title('OFDM symbol boundary Detection');
xlabel('Sampling Index (m)');
ylabel('Autocorrelation J(m)');
end