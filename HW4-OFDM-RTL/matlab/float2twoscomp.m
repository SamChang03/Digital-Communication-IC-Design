function output = float2twoscomp(float_num, int_bit, frac_bit)

total_bit = int_bit + frac_bit-1;
min_val = -(2^(total_bit - 1));
max_val = (2^(total_bit - 1)) - 1;

float_real = real(float_num);
float_img = imag(float_num);

if (float_real < min_val) || (float_real > max_val)
    disp("data out of range")
end

if float_img < min_val || float_img > max_val
    disp("data out of range")
end

if (float_real > 0)
    out_real = floor((float_real)*2^(frac_bit));
else
    out_real = floor(2^total_bit -(float_real)*2^(frac_bit));
end

if (float_img > 0)
    out_imag = floor((float_img)*2^(frac_bit));
else
    out_imag = floor(2^total_bit -(float_img)*2^(frac_bit));
end
output = out_real+ out_imag*1i;