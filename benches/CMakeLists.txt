cmake_minimum_required(VERSION 3.14)
project(my_benchmarks VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable optimizations with debug symbols for profiling
set(CMAKE_BUILD_TYPE RelWithDebInfo)

# Fetch google_benchmark from CodSpeed's repository
include(FetchContent)
FetchContent_Declare(
  google_benchmark
  GIT_REPOSITORY https://github.com/CodSpeedHQ/codspeed-cpp
  SOURCE_SUBDIR google_benchmark
  GIT_TAG main
)

set(BENCHMARK_DOWNLOAD_DEPENDENCIES ON)
FetchContent_MakeAvailable(google_benchmark)

# Create the benchmark executable
add_executable(bench fibonacci.cpp)

# Link against google_benchmark
target_link_libraries(bench benchmark::benchmark)