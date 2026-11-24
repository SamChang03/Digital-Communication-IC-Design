function bitStream = bit_stream_generation(numBits)
% The fuction generate a random binary stream with <<numBits>> bits 

%% Test Parameters %%
%numBits = 2^25; % 33,554,432 bits

%% Generate Bit Stream %%
bitStream = randi([0, 1], 1, numBits, 'uint8');

%% Test # of Bits
disp(['Total Bits: ', num2str(numBits)]);
end