%% Main Fuction of Spilt-Radix Fast Fourier Transform

clear 
close all
clc

%% Mode Setting %%
% mode -1 --> FFT
% mode 1 --> IFFT
mode = -1;

%% Parameters %%
N = 32;
x = randn(1, N);

%% Main Function %%
tic
xhat = SRFFT(x,-1);
%xhat = fft(x);
timeCooleyTukey = toc;

tic
xhatcheck = fft(x);
timeFFTW = toc;

rms = 100 * sqrt(sum(sum(abs(xhat - xhatcheck).^2)) / sum(sum(abs(xhat).^2)));

%% Print Messages %%
fprintf('Time SRFFT_SW = %f; \t Time FFTW = %f\n\n', timeCooleyTukey, timeFFTW);
fprintf('Root mean square with FFTW implementation = %.10e\n', rms);