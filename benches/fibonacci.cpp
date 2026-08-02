#include <benchmark/benchmark.h>

// Recursive Fibonacci function to benchmark
static long long fibonacci(int n) {
  if (n <= 1)
    return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

// Define the benchmark
static void BM_Fibonacci(benchmark::State &state) {
  // Use a volatile variable to prevent compile-time optimization
  volatile int n = 30;

  // This loop runs multiple times to get accurate measurements
  for (auto _ : state) {
    // Prevent compiler from optimizing away the computation
    auto result = fibonacci(n);
    benchmark::DoNotOptimize(result);
  }
}

// Register the benchmark, specifying the time unit as milliseconds for better
// readability
BENCHMARK(BM_Fibonacci)->Unit(benchmark::kMillisecond);

// Entrypoint that runs all registered benchmarks
BENCHMARK_MAIN();