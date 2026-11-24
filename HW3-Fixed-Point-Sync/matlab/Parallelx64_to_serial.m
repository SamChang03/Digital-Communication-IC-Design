function  SerialSymbols = Parallelx64_to_serial (ParallelSymbols)

P_transposed = ParallelSymbols.'; 
SerialSymbols = reshape(P_transposed, [], 1);
end