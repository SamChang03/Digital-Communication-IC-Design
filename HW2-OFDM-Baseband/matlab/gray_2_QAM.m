function symbolQAM = gray_2_QAM(indices,M)

symbolQAM = zeros(1,length(indices));

% Look-Up-Table for QPSK & 16-QAM
for i = 1:length(indices)
    if M == 4
        switch indices(i)
            case 0b00
                symbolQAM(i) = -1-1i;
            case 0b01
                symbolQAM(i) = -1+1i;
            case 0b10
                symbolQAM(i) =  1-1i;
            case 0b11
                symbolQAM(i) =  1+1i;
        end
    elseif M == 16
        switch indices(i)
            case 0b0000
                symbolQAM(i) = -3-3i;
            case 0b0001
                symbolQAM(i) = -3-1i;
            case 0b0011
                symbolQAM(i) = -3+1i;
            case 0b0010
                symbolQAM(i) = -3+3i;

            case 0b0100
                symbolQAM(i) = -1-3i;
            case 0b0101
                symbolQAM(i) = -1-1i;
            case 0b0111
                symbolQAM(i) = -1+1i;
            case 0b0110
                symbolQAM(i) = -1+3i;

            case 0b1100
                symbolQAM(i) =  1-3i;
            case 0b1101
                symbolQAM(i) =  1-1i;
            case 0b1111
                symbolQAM(i) =  1+1i;
            case 0b1110
                symbolQAM(i) =  1+3i;

            case 0b1000
                symbolQAM(i) =  3-3i;
            case 0b1001
                symbolQAM(i) =  3-1i;
            case 0b1011
                symbolQAM(i) =  3+1i;
            case 0b1010
                symbolQAM(i) =  3+3i;
        end
    end
end

% Transpose to show on ConstellationDiagram
symbolQAM = symbolQAM';