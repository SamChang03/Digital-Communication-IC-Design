#include "srfft_head.h"

Complex complex_add(Complex a, Complex b) {
    Complex result;
    result.re = a.re + b.re;
    result.im = a.im + b.im;
    return result;
}