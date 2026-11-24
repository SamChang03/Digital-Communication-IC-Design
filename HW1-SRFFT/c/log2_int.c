#include "srfft_head.h"

int log2_int(int n) {
    int log = 0;
    while (n >>= 1) log++;
    return log;
}