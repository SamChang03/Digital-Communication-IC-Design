#include <stdio.h>
#include <stdlib.h>
#include <complex.h>
#include <math.h>

// 定義圓周率
#define PI 3.14159265358979323846

/**
 * @brief 遞歸式的 Radix-2 Decimation-In-Time (DIT) FFT
 * * @param X 輸入/輸出陣列 (複雜數)。在遞歸呼叫結束時，會包含FFT結果。
 * @param N FFT的點數 (必須是2的冪次)。
 */
void recursive_fft(double complex *X, int N) {
    // 遞歸的終止條件: 當點數 N = 1 時，FFT 結果就是其本身
    if (N <= 1) {
        return;
    }

    // 1. Decimation-In-Time: 將輸入序列 X 分為偶數項 (Even) 和奇數項 (Odd)
    int M = N / 2;
    double complex *X_even = (double complex *)malloc(M * sizeof(double complex));
    double complex *X_odd = (double complex *)malloc(M * sizeof(double complex));

    for (int i = 0; i < M; i++) {
        X_even[i] = X[2 * i];       // 偶數索引項
        X_odd[i] = X[2 * i + 1];    // 奇數索引項
    }

    // 2. Divide: 遞歸地計算兩個 N/2 點的 FFT
    recursive_fft(X_even, M);
    recursive_fft(X_odd, M);

    // 3. Conquer (Butterfly Operation): 組合兩個 N/2 點的 FFT 結果
    for (int k = 0; k < M; k++) {
        // 計算旋轉因子 (Twiddle Factor): W_N^k = exp(-j * 2 * PI * k / N)
        double complex Wk = cexp(-I * 2.0 * PI * k / N);

        // 核心的蝶形運算 (Butterfly Operation):
        // X[k]      = X_even[k] + W_N^k * X_odd[k]
        // X[k + M]  = X_even[k] - W_N^k * X_odd[k]
        double complex T = Wk * X_odd[k]; // T = Twiddle Factor * Odd part

        X[k]     = X_even[k] + T;
        X[k + M] = X_even[k] - T;
    }

    // 釋放遞歸呼叫中分配的記憶體
    free(X_even);
    free(X_odd);
}

// ================= 主程式範例 ==================

void print_spectrum(const char *label, double complex *X, int N) {
    printf("%s (N=%d):\n", label, N);
    for (int i = 0; i < N; i++) {
        printf("  X[%d] = %+.4f %+.4f*i\n", i, creal(X[i]), cimag(X[i]));
    }
    printf("---------------------------\n");
}

int main() {
    // FFT 點數 N (必須是 2 的冪次, 例如 8, 16, 32...)
    const int N = 8; 

    // 測試訊號 (實數輸入，虛部為 0)
    // 範例：x(n) = {1, 0, 0, 0, 0, 0, 0, 0} -> 8點FFT結果應為 {1, 1, 1, 1, 1, 1, 1, 1}
    // 範例：x(n) = {1, 0, 0, 0, 1, 0, 0, 0} (直流+奈奎斯特頻率)
    double complex input_data[N] = {
        1.0 + 0.0 * I,
        0.0 + 0.0 * I,
        0.0 + 0.0 * I,
        0.0 + 0.0 * I,
        1.0 + 0.0 * I,
        0.0 + 0.0 * I,
        0.0 + 0.0 * I,
        0.0 + 0.0 * I
    };

    // 由於 FFT 會在原陣列上操作 (in-place)，我們複製一份輸入數據
    double complex *fft_result = (double complex *)malloc(N * sizeof(double complex));
    for (int i = 0; i < N; i++) {
        fft_result[i] = input_data[i];
    }
    
    print_spectrum("Input Signal", input_data, N);
    
    // 執行遞歸 FFT
    recursive_fft(fft_result, N);

    print_spectrum("FFT Result", fft_result, N);

    free(fft_result);
    return 0;
}