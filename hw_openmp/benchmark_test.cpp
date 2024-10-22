#include <omp.h>
#include <iostream>
#include <chrono>

void multiplymatrix(float a[], float b[], float c[], int n);
void multiplymatrix3(float a[], float b[], float c[], int n);
void transpose(float* b, float* b_transposed, int n);
void multiplymatrix_transposed(float a[], float b_transposed[], float c[], int n);

void benchmark_multiply(int n, int num_threads) {
    float* a = new float[n*n];
    float* b = new float[n*n];
    float* c = new float[n*n];

    // Create identity matrices
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            a[i * n + j] = (i == j) ? 1.0f : 0.0f;
            b[i * n + j] = (i == j) ? 1.0f : 0.0f;
        }
    }

    // Benchmark original multiplymatrix
    omp_set_num_threads(1);
    auto start = std::chrono::high_resolution_clock::now();
    multiplymatrix(a, b, c, n);
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration = end - start;
    std::cout << "Original multiplymatrix with 1 thread: " << duration.count() << " seconds\n";

    // Benchmark optimized multiplymatrix3
    omp_set_num_threads(num_threads);
    start = std::chrono::high_resolution_clock::now();
    multiplymatrix3(a, b, c, n);
    end = std::chrono::high_resolution_clock::now();
    duration = end - start;
    std::cout << "Optimized multiplymatrix3 with " << num_threads << " threads: " << duration.count() << " seconds\n";

    float* b_transposed = new float[n*n];
    transpose(b, b_transposed, n);

    // Benchmark transposed multiplymatrix
    omp_set_num_threads(num_threads);
    start = std::chrono::high_resolution_clock::now();
    multiplymatrix_transposed(a, b_transposed, c, n);
    end = std::chrono::high_resolution_clock::now();
    duration = end - start;
    std::cout << "Transposed multiplymatrix with " << num_threads << " threads: " << duration.count() << " seconds\n";

    delete[] a;
    delete[] b_transposed;
    delete[] b;
    delete[] c;
}

void benchmark_diagonal_matrices(int n, int num_threads) {
    float* a = new float[n*n];
    float* b = new float[n*n];
    float* c = new float[n*n];

    // Create matrices with main diagonal 3 and others 2
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            a[i * n + j] = (i == j) ? 3.0f : 2.0f;
            b[i * n + j] = (i == j) ? 3.0f : 2.0f;
        }
    }

    // Benchmark optimized multiplymatrix3
    omp_set_num_threads(num_threads);
    auto start = std::chrono::high_resolution_clock::now();
    multiplymatrix3(a, b, c, n);
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration = end - start;
    std::cout << "Diagonal matrices multiplymatrix3 with " << num_threads << " threads: " << duration.count() << " seconds\n";

    delete[] a;
    delete[] b;
    delete[] c;
}

int main() {
    int n = 1024;

    std::cout << "Benchmarking with identity matrices:\n";
    benchmark_multiply(n, 1);
    benchmark_multiply(n, 2);
    benchmark_multiply(n, 4);
    benchmark_multiply(n, 8);

    std::cout << "\nBenchmarking with diagonal matrices:\n";
    benchmark_diagonal_matrices(n, 1);
    benchmark_diagonal_matrices(n, 2);
    benchmark_diagonal_matrices(n, 4);
    benchmark_diagonal_matrices(n, 8);

    return 0;
}
