function x_truncated = truncation(x, int_bit, frac_bit)
% Truncation operation in a fixed-point system, supporting complex numbers.

    % Input Validation
    if ~isscalar(int_bit) || ~isscalar(frac_bit) || int_bit < 0 || frac_bit < 0
        error('int_bit and frac_bit must be non-negative scalars.');
    end

    % Calculate Fixed-Point Parameters
    quantization_step = 2^(-frac_bit);
    
    % Max/Min values
    max_val = 2^int_bit - quantization_step; 
    min_val = -2^int_bit; 

    % Truncation/Saturation Main Function
    function component_out = apply_truncation(component_in)
        
        % Main Truncation (Quantization using floor)
        component_out = floor(component_in./ quantization_step) * quantization_step;
        
        % Saturation (Overflow Handling)
        % Clamp the value within the representable fixed-point range.
        component_out(component_out > max_val) = max_val;
        component_out(component_out < min_val) = min_val;
    end
    
    % Deal With Real or Complex Input
    
    if isreal(x)
        % If purely real, apply logic directly
        x_truncated = apply_truncation(x);
    else
        % If complex, process Real and Imaginary parts independently
        
        % Truncate and saturate the Real part
        real_part_out = apply_truncation(real(x));
        
        % Truncate and saturate the Imaginary part
        imag_part_out = apply_truncation(imag(x));
        
        % Reconstruct the complex number
        x_truncated = real_part_out + 1i * imag_part_out;
    end
end