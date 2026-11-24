function y = SRFFT(x,mode)
% Spilt-Radix Fast Fourier Transform
% mode -1 --> FFT
% mode 1 --> IFFT

N = length(x);
log2n = log2(N);

% Bit Reverse
x = bitrevorder(x);

% FFT Operation
for stage = 1 : log2n
    group_member = 2^(stage); 
    node_spacing = group_member/2;
    wm = twiddle_factor(1,group_member,mode);
    % Group Loop
    for index = 0 : group_member : N-1
        w= 1.0+0.0j;
        % Butterfly Loop
        for k= 0 : node_spacing-1
            t = x(index+k+node_spacing+1)*w;
            u = x(index+k+1);
            x(index+k+1) = u + t;
            x(index+k+node_spacing+1) = u - t;
            w = w*wm;
        end
    end
end
% Normalize
y = x./sqrt(N);

