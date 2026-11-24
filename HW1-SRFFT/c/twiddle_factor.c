#include"srfft_head.h"


// Twiddle factor computation with optimization for common cases
Complex twiddle_factor(int k, int n, int mode) {
    // Optimize for common cases
    Complex result;
    if (k == 0){ result.re = 1; result.im = 0;}
    if (k * 4 == n) { result.re = 0; result.im = (mode == -1) ? -1 : 1 ;}
    if (k * 2 == n) { result.re = -1; result.im = 0;}
    if (k * 4 == 3 * n) { result.re = 0; result.im = (mode == -1) ? 1 : -1 ;}
    
    double angle = mode * TWO_PI * k / n;
    result.re = cos(angle);
    result.im = sin(angle);
    return result;
}