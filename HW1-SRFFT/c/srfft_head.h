#include <stdio.h>
#include <stdlib.h>
#include <complex.h>
#include <math.h>


// Constants
#define PI 3.14159265358979323846
#define TWO_PI (2.0 * PI)
#define MODE_FFT -1
#define MODE_IFFT 1

// Complex number type
typedef double complex complex_t;

typedef struct {
    double re;
    double im;
} Complex;

void srfft(double* x_re ,double* x_im , double n, double mode);
int log2_int(int n);
int bit_reverse(unsigned int x, int log2n);
Complex twiddle_factor(int k, int n, int mode) ;
Complex complex_mul(Complex a, Complex b);
