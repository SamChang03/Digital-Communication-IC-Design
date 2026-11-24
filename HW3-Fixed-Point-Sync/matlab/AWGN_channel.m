function ChannelOut= AWGN_channel(ChannelIn,SNR_dB)

%% Calculate Signal Power %%
Ps = mean(abs(ChannelIn).^2);
disp(['Signal Power (Ps): ', num2str(Ps)]);

%% Design Noise Power (Given SNR) %%
SNR_lin = 10^(SNR_dB / 10);
Pn_sigma2 = Ps / SNR_lin;

%% Noise Generator %%

% Calculate Standard Deviation
sigma_std = sqrt(Pn_sigma2 / 2);

% Generate Gaussian Noise
noise_I = sigma_std * randn(size(ChannelIn)); % Real Part
noise_Q = sigma_std * randn(size(ChannelIn)); % Imaginary Part

noise = noise_I + 1i * noise_Q;

% Check Noise Power
Pn_check = mean(abs(noise).^2);
disp(['Noise Power (Pn): ', num2str(Pn_check)]);

%% Channel Output %%
ChannelOut = ChannelIn + noise;

%% Check Result (For Debugging)%%
disp(['Check SNR (Ps/Pn): ', num2str(10*log10(Ps / Pn_check)), ' dB']); 
end