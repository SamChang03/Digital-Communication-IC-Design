#include "srfft_head.h"

int bit_reverse(unsigned int x, int log2n) {
    unsigned int r = 0;
    for (int i = 0; i < log2n; i++) {
        r = (r << 1) | (x & 1);
        x >>= 1;
    }
    return r;
}