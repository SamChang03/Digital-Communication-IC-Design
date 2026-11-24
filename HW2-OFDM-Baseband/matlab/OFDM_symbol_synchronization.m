function FFTstartIndex = OFDM_symbol_synchronization(OFDMnoise,FFTsize,numCP,AutoNum)
%% Parameter Setting %%
numSymbolOFDM = FFTsize + numCP;

search_length = AutoNum * numSymbolOFDM; % search AutoNum symbols

% Signal Slice
SignalCP = OFDMnoise(1:search_length);
LengthSignalIn = length(SignalCP);

Auto = zeros(LengthSignalIn - FFTsize, 1);
Power = zeros(LengthSignalIn - FFTsize, 1); % Power for Normalization

%% Autocorrelation %%
for m = 1 : (LengthSignalIn - FFTsize - numCP)
    
    % --- Portion for Autocorrelation  ---
    % Get r(m+k) (Copied Signals: last 16 OFDM signal)
    rTail = SignalCP(m + FFTsize : m + FFTsize + numCP - 1); 
    % Get r(m+k+N_FFT) (CP Signals)
    rHead = SignalCP(m : m + numCP - 1); 
    
    % --- Calculate Autocorrelation ---
    Auto(m) = sum(conj(rHead) .* rTail); 
    
    % --- Calculate Power ---
    % Power(m) = sum |r(m+k+N_FFT)|^2
    Power(m) = sum(abs(rTail).^2);
end

%% normalized Autocorrelation (Reduce the power factor)
% Cost Function: J(m) = |P(m)|^2 / M(m)^2
normAuto = (abs(Auto).^2) ./ (Power.^2);

%% Find Peak %%
[pks, locs] = findpeaks(normAuto, 'MinPeakHeight', 0.75, 'MinPeakDistance', numSymbolOFDM/2);

% Trim Mean
numPeaks = length(locs);

for i = 2: numPeaks-1
    if mod (locs(i),numSymbolOFDM) > numSymbolOFDM/2
        locs(i) = 0;
    end
end

% Offset Removal
CPstartIndex = round(mod(sum(locs(2:numPeaks-1)),numSymbolOFDM)/(numPeaks-2)) ;
disp(['CP start: ', num2str(CPstartIndex)]);
    
% Real Start point of FFT (end of CP, Data start)
FFTstartIndex = CPstartIndex + numCP;
%FFTstartIndex = CPstartIndex;
disp(['FFT symbol boundary Detection: ', num2str(FFTstartIndex)]);

%% Plot %%
%{
figure(3)
plot(normAuto);
hold on;
plot(locs, pks, 'ro', 'MarkerFaceColor', 'r');
title('OFDM symbol boundary Detection');
xlabel('Sampling Index (m)');
ylabel('Autocorrelation J(m)');
%}