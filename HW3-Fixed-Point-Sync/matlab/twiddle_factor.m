% --- Radix-2 Decimation In Frequency - Iterative approach

function y = twiddle_factor(k,n,mode)
% mode -1 --> FFT
% mode 1 --> IFFT


if (k==0)
    y = 1;
elseif (k * 4 == n)
    if (mode == -1)
        y = -1i;
    else
        y = 1i;
    end
elseif (k * 2 == n)
    y = -1.0;
elseif (k * 4 == 3* n)
    if (mode == -1)
        y = 1i;
    else
        y = -1i;
    end
else
    angle = mode * 2 * pi * k/n;
    y = exp(1i*angle);
end



