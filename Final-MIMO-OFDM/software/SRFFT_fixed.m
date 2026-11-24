function y = SRFFT_fixed(x,mode,int_bit,frac_bit)
% Spilt-Radix Fast Fourier Transform
% mode -1 --> FFT
% mode 1 --> IFFT

% parameter setting DO NOT NEED TRUNCATION
N = length(x);
log2n = log2(N);

% Bit Reverse
x = bitrevorder(x);

% FFT Operation
for stage = 1 : log2n
    group_member = 2^(stage); 
    node_spacing = group_member/2;
    wm = truncation(twiddle_factor(1,group_member,mode),int_bit,frac_bit);
    % Group Loop
    for index = 0 : group_member : N-1
        w= 1.0+0.0j;
        % Butterfly Loop
        for k= 0 : node_spacing-1
            t = truncation(x(index+k+node_spacing+1)*w,int_bit,frac_bit);
            u = x(index+k+1);
            x(index+k+1) = truncation(u + t,int_bit,frac_bit);
            x(index+k+node_spacing+1) = truncation(u - t,int_bit,frac_bit);
            w = truncation(w*wm,int_bit,frac_bit);
        end
    end
end
% Normalize
y=truncation(x/sqrt(N),int_bit,frac_bit);


