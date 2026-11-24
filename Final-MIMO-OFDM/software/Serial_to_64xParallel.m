function  paralleldSymbols = Serial_to_64xParallel (serialSymbols,FFTsize)

% Group Size
%FFTsize = 64; 

% # of Groups
L_groups = length(serialSymbols) / FFTsize;


paralleldSymbols = reshape(serialSymbols, FFTsize, L_groups).';
end
