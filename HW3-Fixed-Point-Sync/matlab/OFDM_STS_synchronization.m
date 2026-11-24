function STS_start_index = OFDM_STS_synchronization(OFDMnoisePreamble, FFT_SIZE,SEARCH_WINDOW)
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
    Power(m) = sum(abs(r_m_plus_delay).^2); 
end

%% Normalization
normAuto = (abs(Auto).^2) ./ (Power.^2);

%% 2. Find the Plateau Start

% Threshold for detection 
THRESHOLD = 0.5; 
[~, locs] = findpeaks(normAuto, 'MinPeakHeight', THRESHOLD, 'MinPeakDistance', 5);

if isempty(locs)
    warning('STS Coarse Synchronization Failed: Could not detect the preamble.');
    STS_start_index = -1;
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
%% Plot %%
figure(1)
plot(normAuto);
%hold on;
%plot(locs, pks, 'ro', 'MarkerFaceColor', 'r');
title('OFDM symbol boundary Detection');
xlabel('Sampling Index (m)');
ylabel('Autocorrelation J(m)');
end