#include "srfft_head.h"

void srfft(double* x_re ,double* x_im , double n, double mode) {
    
    int log2n = log2_int(n);

    // Bit-reversal permutation
    for (int i = 0; i < n; i++) {
        int j = bit_reverse(i, log2n);
        if (i < j) {
            double temp_re = x_re[i];
            x_re[i] = x_re[j];
            x_re[j] = temp_re;

            double temp_im = x_im[i];
            x_im[i] = x_im[j];
            x_im[j] = temp_im;
        }
    }
    
    for (int stage = 1; stage <= log2n; stage++) {
        int m = 1 << stage;      // Current stage size
        int m2 = m >> 1;         // butterfly pair distance
        Complex wm = twiddle_factor(1, m, mode);
        
        for (int k = 0; k < n; k += m) {
            Complex w;
            w.re = 1.0;
            w.im = 0;
            for (int j = 0; j < m2; j++) {

                int idx1 = k + j;       // Upper arm index (u)
                int idx2 = k + j + m2;  // Lower arm index (v)

                Complex t;
                Complex u;

                // Read u (Upper Arm: x[idx1])
                u.re = x_re[idx1];
                u.im = x_im[idx1];
                
                // Read v (Lower Arm: x[idx2])
                Complex v;
                v.re = x_re[idx2];
                v.im = x_im[idx2];
                
                // Calculate t = v * w 
                t = complex_mul(v, w); 
                
                // Update Upper Arm: x[idx1] = u + t
                x_re[idx1] = u.re + t.re;
                x_im[idx1] = u.im + t.im;
                
                // Update Lower Arm: x[idx2] = u - t
                x_re[idx2] = u.re - t.re;
                x_im[idx2] = u.im - t.im;

                // Update Twiddle Factor for the next pair: w = w * w_m
                w = complex_mul(w, wm);
            }
        }
    }
    if (mode == MODE_IFFT)
    {
        for (int i = 0; i < n; i++)
        {
            x_re[i] /= n;
            x_im[i] /= n;
        }  
    }
    
}