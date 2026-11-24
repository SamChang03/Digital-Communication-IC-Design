function modulatedSymbols = QAM_mapping(bitStream,M)
% QAM Mapping M=4 QPSK; M=16 16-QAM

%% Test Parameters %%
%M = 16; 
%numBits = 10000; 
%bitStream = randi([0 1], numBits, 1, 'uint8');

%% QAM Mudulation Main

% A M-QAM symbol need k=log2(M) bits 
% QPSK:M=4 k=2; 16-QAM: M=16, k=4
k = log2(M); 

% Bit Grouping
numBits = length(bitStream);
numSymbols = numBits / k;
bitGroups = reshape(bitStream, k, numSymbols);

% LUT for Gray Code to QAM
indices = bit2int(bitGroups, k, true);
modulatedSymbols = gray_2_QAM(indices,M);

% Normalization
NormlizeFactor = sqrt(3/(2*(M-1)));
modulatedSymbols = NormlizeFactor*modulatedSymbols; % normalized modulatedSymbols / avgPower
disp(['Check Signal Power: ', num2str(mean(abs(modulatedSymbols).^2))])


% Test Gray Code
%{
if M==4
    TestArray = [0b00,0b01,0b11,0b10];% Test QPSK
elseif M==16
    TestArray = [0b0000,0b0001,0b0011,0b0010, ...
                 0b0110,0b0111,0b0101,0b0100, ...
                 0b1100,0b1101,0b1111,0b1110, ...
                 0b1010,0b1011,0b1001,0b1000];% Test 16-QAM
end
modulatedSymbolsTest = gray_2_QAM(TestArray,M);
modulatedSymbolsTest = NormlizeFactor*modulatedSymbolsTest;


%% Plot for Test

index_strings = arrayfun(@(x) ['index', num2str(x)], 0:M, 'UniformOutput', false);
if M==4
    first_element = {'QPSK'};
elseif M==16
    first_element = {'16-QAM'};
end

final_cell_array = [first_element, index_strings];

h = comm.ConstellationDiagram('NumInputPorts', 2, ...
                              'ChannelNames',final_cell_array, ...
                              'XLimits',[-1.5,1.5],'YLimits',[-1.5,1.5]);
h.ReferenceConstellation = 0;
h(modulatedSymbols,modulatedSymbolsTest');
%}
end