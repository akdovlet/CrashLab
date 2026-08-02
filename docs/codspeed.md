> ## Documentation Index
> Fetch the complete documentation index at: https://codspeed.io/docs/llms.txt
> Use this file to discover all available pages before exploring further.

# Writing Benchmarks in C++

> Create benchmarks for your C++ codebase using `google_benchmark`

export const CIWorkflow = ({minimal = false, enableWorkflowDispatch = true, runsOn = "ubuntu-latest", highlight = [], mode, modes, submodules = false, preSteps = [], buildSteps = ["# ...", "# Setup your environment here:", "#  - Configure your Python/Rust/Node version", "#  - Install your dependencies", "#  - Build your benchmarks (if using a compiled language)", "# ..."], benchmarkCommand = ["<Insert your benchmark command here>"], jobName = "Run benchmarks", env = {}}) => {
  const modeList = modes || (mode ? [mode] : undefined);
  if (!modeList || modeList.length === 0) {
    throw new Error("mode or modes is required");
  }
  const indent = (lines, depth) => {
    const reindentedLines = lines.map(l => l.length === 0 ? l : (" ").repeat(depth) + l);
    return reindentedLines.join("\n");
  };
  const workflowDispatchSection = enableWorkflowDispatch ? "  # `workflow_dispatch` allows CodSpeed to trigger backtest\n" + "  # performance analysis in order to generate initial data.\n" + "  workflow_dispatch:\n" : "";
  let yaml = "";
  if (!minimal) {
    yaml += `
name: CodSpeed Benchmarks

on:
  push:
    branches:
      - "main" # or "master"
  pull_request:
`;
    yaml += workflowDispatchSection;
  }
  yaml += `
jobs:
  benchmarks:
    name: ${jobName}
    runs-on: ${runsOn}`;
  if (!minimal) {
    yaml += `
    permissions: # optional for public repositories
      contents: read # required for actions/checkout
      id-token: write # required for OIDC authentication with CodSpeed`;
  }
  if (preSteps.length > 0) yaml += "\n" + indent(preSteps, 4);
  yaml += `
    steps:
      - uses: actions/checkout@v5`;
  if (submodules) {
    const value = typeof submodules === "string" ? submodules : "true";
    yaml += `\n        with:\n          submodules: ${value}`;
  }
  yaml += "\n" + indent(buildSteps, 6);
  const modeValue = modeList.join(",");
  yaml += `
      - name: Run the benchmarks
        uses: CodSpeedHQ/action@v5
        with:
          mode: ${modeValue}`;
  if (benchmarkCommand.length > 0) {
    const indentedBenchCommand = benchmarkCommand.length > 1 ? benchmarkCommand[0] + "\n" + indent(benchmarkCommand.slice(1), 12) : benchmarkCommand;
    const runLine = indent(["run: "], 10) + indentedBenchCommand;
    yaml += `\n${runLine}`;
  }
  const envEntries = Object.entries(env);
  if (envEntries.length > 0) {
    const envLines = ["env:", ...envEntries.map(([k, v]) => `  ${k}: ${v}`)];
    yaml += "\n" + indent(envLines, 8);
  }
  return <CodeBlock language="yaml" highlight={JSON.stringify(highlight)} {...minimal || ({
    filename: ".github/workflows/codspeed.yml",
    icon: "github"
  })}>
      {yaml}
    </CodeBlock>;
};

To use CodSpeed in your C++ codebase, you can use
[CodSpeed's `google_benchmark` library](https://github.com/CodSpeedHQ/codspeed-cpp/tree/main/google_benchmark),
which is a compatibility layer to run both instrumented and walltime CodSpeed
benchmarks.

## Writing benchmarks

CodSpeed integrates with the `google_benchmark` library. Here is a small example
on how to declare benchmarks. Otherwise, any existing benchmarks of your project
can be reused.

```cpp main.cpp theme={null}
// Define the function under test
static void BM_StringCopy(benchmark::State &state) {
  std::string x = "hello";

  // Google benchmark relies on state.begin() and state.end() to run the benchmark and count iterations
  for (auto _ : state) {
    std::string copy(x);

    // Use DoNotOptimize and ClobberMemory to prevent the compiler optimizing away your benchmark
    // See: https://google.github.io/benchmark/user_guide.html#preventing-optimization
    benchmark::DoNotOptimize(copy);
    benchmark::ClobberMemory();
  }
}
// Register the benchmarked to be called by the executable
BENCHMARK(BM_StringCopy);

static void BM_memcpy(benchmark::State &state) {
  char *src = new char[state.range(0)];
  char *dst = new char[state.range(0)];
  memset(src, 'x', state.range(0));
  for (auto _ : state) {
    memcpy(dst, src, state.range(0));
    benchmark::DoNotOptimize(dst);
    benchmark::ClobberMemory();
  }
  delete[] src;
  delete[] dst;
}

BENCHMARK(BM_memcpy)->Range(8, 8 << 10);

// Entrypoint of the benchmark executable
BENCHMARK_MAIN();
```

<Note>
  Make sure that your benchmarks aren't optimized away by the compiler by using
  `benchmark::DoNotOptimize` and `benchmark::ClobberMemory`. See [Prevent
  Compiler
  Optimizations](/docs/guides/how-to-benchmark-cpp-with-google-benchmark#prevent-compiler-optimizations)
  for more information.
</Note>

For a deeper dive into writing benchmarks with Google Benchmark, see:

<Card title="How to Benchmark C++ with Google Benchmark" icon="https://mintcdn.com/codspeed/GDLcp8Ny8u4pFbNX/assets/icons/cpp.svg?fit=max&auto=format&n=GDLcp8Ny8u4pFbNX&q=85&s=420e72f7613b61e7f1961ccdd2e4b9bb" href="/docs/guides/how-to-benchmark-cpp-with-google-benchmark" horizontal width="31" height="31" data-path="assets/icons/cpp.svg">
  An in-depth guide to writing Google Benchmark benchmarks: fixtures,
  parameterized benchmarks, custom counters, and CodSpeed CI integration.
</Card>

## Building & Running benchmarks

To build and run benchmarks, CodSpeed officially support usage of the
`google_benchmark` library using both [`CMake`](#cmake) and [`Bazel`](#bazel).
If you are using another build system, you may find guidelines in the
[custom build systems section](#custom-build-systems)

### CMake

To use CodSpeed's `google_benchmark` integration using
[`CMake`](https://cmake.org/documentation/), you can declare a benchmark
executable as follows:

```cmake CMakeLists.txt theme={null}
cmake_minimum_required(VERSION 3.12)
include(FetchContent)

project(my_codspeed_project VERSION 0.0.0 LANGUAGES CXX)

# Enable release mode with debug symbols to display useful profiling data
set(CMAKE_BUILD_TYPE RelWithDebInfo)

set(BENCHMARK_DOWNLOAD_DEPENDENCIES ON)

FetchContent_Declare(
    google_benchmark
    GIT_REPOSITORY https://github.com/CodSpeedHQ/codspeed-cpp # Target the codspeed cpp repository
    SOURCE_SUBDIR google_benchmark # Make sure to target the google_benchmark subdirectory
    GIT_TAG main # Or chose a specific version or git ref, check the releases page on the repository
)

FetchContent_MakeAvailable(google_benchmark)

# Declare your benchmark executable and its sources here
add_executable(my_benchmark_executable benches/bench.cpp)

# Link your executable against the `benchmark::benchmark`, the `google_benchmark` library
# Note: the first argument must match the first argument of the `add_executable` call
target_link_libraries(my_benchmark_executable benchmark::benchmark)
```

<Info>
  Checkout the
  [releases page](https://github.com/CodSpeedHQ/codspeed-cpp/releases) if you want
  to target a specific version of the library.
</Info>

<Tip>
  This example is a dedicated `CMakeLists.txt` file for the benchmark executable.
  You can also add an executable target to your existing project's
  `CMakeLists.txt`. Make sure to link this target against the
  `benchmark::benchmark` library.
</Tip>

#### Building benchmarks

To build the benchmark executable, run:

```shellsession title=terminal icon="square-terminal" theme={null}
$ mkdir build && cd build

$ cmake -DCODSPEED_MODE=simulation ..
-- The CXX compiler identification is GNU 14.2.1
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- ...
-- Configuring done (8.6s)
-- Generating done (0.1s)
-- Build files have been written to: /home/user/project-benchmark/build

$ make
[  1%] Building CXX object ...
 ...
 ...
[100%] Built target my_benchmark_executable
```

#### The `CODSPEED_MODE` flag

Please note the `-DCODSPEED_MODE=simulation` flag in the `cmake` command. This
will enable the CodSpeed CPU simulation mode for the benchmark executable, where
each benchmark is run only once on a simulated CPU.

If you omit the `CODSPEED_MODE` cmake flag, CodSpeed will not be enabled in the
benchmark executable, and it will run as a regular benchmark.

The CODSPEED\_MODE cmake flag can take the following values:

* `off`: defaulted to when the cmake flag is not provided, disables codspeed.
* `simulation`: benchmarks are run only once on a simulated CPU.
* `walltime`: used for walltime codspeed reports, see
  [dedicated documentation](/docs/instruments/walltime)
* `memory`: benchmarks are run once using
  [memory profiling](/docs/instruments/memory)
* `instrumentation`: (deprecated) alias of `simulation`.

#### Debug symbols

In order to get the most out of CodSpeed reports, debug symbols need to be
enabled within your executable. In the [example](#cmake) above, this is done by
setting `CMAKE_BUILD_TYPE` to `RelWithDebInfo`.

#### Running the benchmarks locally

Simply execute the compiled binary to run the benchmarks.

```shellsession title=terminal icon="square-terminal" theme={null}
$ ./benchmark_example
Codspeed mode: simulation
2025-02-27T16:15:03+01:00
Running ./benchmark_example
Run on (12 X 4500 MHz CPUs)
CPU Caches:
  L1 Data 48 KiB (x6)
  L1 Instruction 32 KiB (x6)
  L2 Unified 1280 KiB (x6)
  L3 Unified 12288 KiB (x1) Load Average: 1.73, 1.71, 1.52
NOTICE: codspeed is enabled, but no performance measurement will be made since it's running in an unknown environment.
Checked: benches/main.cpp::BM_rand_vector
Checked: benches/main.cpp::BM_StringCopy
Checked: benches/main.cpp::BM_memcpy[8]
Checked: benches/main.cpp::BM_memcpy[64]
Checked: benches/main.cpp::BM_memcpy[512]
Checked: benches/main.cpp::BM_memcpy[4096]
Checked: benches/main.cpp::BM_memcpy[8192]
```

Congratulations ! 🎉 You can now
[run those benchmark in your CI](#running-the-benchmarks-in-your-ci) to get the
actual performance measurements.

#### Running the benchmarks in your CI

To generate performance reports, you need to run the benchmarks in your CI. This
allows CodSpeed to automatically run benchmarks and warn you about regressions
during development.

<Tip>
  If you want more details on how to configure the CodSpeed action, you can check
  out the [Continuous Reporting section](/docs/integrations/ci).
</Tip>

Here is an example of a GitHub Actions workflow that runs the benchmarks and
reports the results to CodSpeed on every push to the `main` branch and every
pull request:

<CIWorkflow
  mode="simulation"
  buildSteps={[
"- name: Build the benchmark target(s)",
"  run: |",
"    mkdir build",
"    cd build",
"    cmake -DCODSPEED_MODE=simulation ..",
"    make -j",
]}
  benchmarkCommand={[
"./build/my_benchmark_executable  # Replace with the proper executable path",
]}
/>

#### Running benchmarks in parallel CI jobs

If your benchmarks are taking too much time to run under the CodSpeed action,
you can run them in parallel to speed up the execution.

To parallelize your benchmarks, first split them in multiple executables that
each run a subset of your benches.

```cmake CMakelists.txt theme={null}
# Create individual benchmark executables
set(BENCHMARKS first_bench second_bench third_bench)

# Add `bench_name` target with `bench_name.cpp` source for each bench listed above
foreach(benchmark IN LISTS BENCHMARKS)
  add_executable(${benchmark} benches/${benchmark}.cpp)
  target_link_libraries(${benchmark}
    benchmark::benchmark
  )
endforeach()

# Create a custom target to run all benchmarks locally
add_custom_target(run_all_benchmarks
  COMMAND ${CMAKE_COMMAND} -E echo "Running all benchmarks..."
)
# Register each benchmark target as a dependency of
foreach(benchmark IN LISTS BENCHMARKS)
  add_custom_command(
    TARGET run_all_benchmarks
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "Running ${benchmark}..."
    COMMAND $<TARGET_FILE:${benchmark}>
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  )
endforeach()
```

Then update your CI workflow to run benchmarks executable by executable

<CIWorkflow
  minimal
  mode="simulation"
  highlight={[5, 6, 7, 15, 20]}
  preSteps={[
"strategy:",
"  matrix:",
"    target: [first_bench, second_bench, third_bench]",
]}
  buildSteps={[
"- name: Build the benchmark target",
"  run: |",
"    mkdir build",
"    cd build",
"    cmake -DCODSPEED_MODE=simulation ..",
"    make -j ${{ matrix.target }}",
]}
  benchmarkCommand={["./build/${{ matrix.target }}"]}
/>

<Info>
  To combine measurement modes like simulation and memory, check out the
  documentation on [running multiple instruments
  serially](/docs/integrations/ci/github-actions/configuration#running-multiple-instruments-serially).
</Info>

### Bazel

You can also use CodSpeed's `google_benchmark` integration with the
[`Bazel`](https://bazel.build/reference) integration.

#### Building benchmarks

Import the library from the
[Bazel Central Registry](https://registry.bazel.build/modules/codspeed_google_benchmark_compat/)
in your `MODULE.bazel` file

```python MODULE.bazel theme={null}
module(name = "my_module")
# Starting from 2.0.0, codspeed_google_benchmark_compat is available from the Bazel central registry
bazel_dep(name = "codspeed_google_benchmark_compat", version = "2.0.0")
```

Then, define your benchmark target in your packages's `BUILD.bazel` file:

```python path/to/bench/BUILD.bazel theme={null}
cc_binary(
    name = "my_benchmark", # Name of your benchmark target
    srcs = glob(["*.cpp", "*.hpp"]), # Or define sources however you wish
    deps = ["@codspeed_google_benchmark_compat//:benchmark"],
)
```

Finally, you can build the benchmarks by running:

```shellsession title=terminal icon="square-terminal" theme={null}
$ bazel build //path/to/bench:my_benchmark \
    --@codspeed_google_benchmark_compat//:codspeed_mode=simulation --compilation_mode=dbg \
    --copt=-O2
INFO: Analyzed target //examples/google_benchmark:my_benchmark (0 packages loaded, 0 targets configured).
INFO: Found 1 target...
Target //examples/google_benchmark:my_benchmark up-to-date:
  bazel-bin/examples/google_benchmark/my_benchmark
INFO: Elapsed time: 0.138s, Critical Path: 0.00s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
```

#### Build options

As you may have noticed in the example, there are a few key build options
essential for bazel to make full use of the CodSpeed library.

* `--@codspeed_google_benchmark_compat//:codspeed_mode=simulation` enables the
  codspeed features of the library, which can take the following values here:
  * `off`: defaulted to when the cli flag is not provided, disables codspeed.
  * `simulation`: benchmarks are run only once on a simulated CPU.
  * `walltime`: used for walltime codspeed reports, see
    [dedicated documentation](/docs/instruments/walltime)
  * `memory`: benchmarks are run once using
    [memory profiling](/docs/instruments/memory)
  * `instrumentation`: (deprecated) alias of `simulation`.
* `--compilation_mode=dbg`: enables debug symbols in the compiled binary, used
  to generate meaningful CodSpeed reports.
* `--copt=-O2`: sets the desired level of compiler optimizations in the
  benchmarks binary.

<Tip>
  **Setting default build options**

  If you do not want to specify these flags every time, you can create a
  `.bazelrc` file at the root of the bazel workspace with the following content

  ```sh theme={null}
  build --@codspeed_cpp//core:codspeed_mode=simulation
  build --compilation_mode=dbg
  build --copt=-O2
  ```
</Tip>

#### Running the benchmarks locally

You can then run your benchmarks by running:

```shellsession title=terminal icon="square-terminal" theme={null}
$ bazel run //path/to/bench:my_benchmark \
    --@codspeed_cpp//core:codspeed_mode=simulation
... Cached build step ...
Codspeed mode: simulation
2025-02-27T16:15:03+01:00
Running ./benchmark_example
Run on (12 X 4500 MHz CPUs)
CPU Caches:
  L1 Data 48 KiB (x6)
  L1 Instruction 32 KiB (x6)
  L2 Unified 1280 KiB (x6)
  L3 Unified 12288 KiB (x1) Load Average: 1.73, 1.71, 1.52
NOTICE: codspeed is enabled, but no performance measurement will be made since it's running in an unknown environment.
Checked: benches/main.cpp::BM_rand_vector
Checked: benches/main.cpp::BM_StringCopy
Checked: benches/main.cpp::BM_memcpy[8]
Checked: benches/main.cpp::BM_memcpy[64]
Checked: benches/main.cpp::BM_memcpy[512]
Checked: benches/main.cpp::BM_memcpy[4096]
Checked: benches/main.cpp::BM_memcpy[8192]
```

#### Running the benchmarks in your CI

To generate performance reports, you need to run the benchmarks in your CI. This
allows CodSpeed to automatically run benchmarks and warn you about regressions
during development.

<Tip>
  If you want more details on how to configure the CodSpeed action, you can check
  out the [Continuous Reporting section](/docs/integrations/ci).
</Tip>

Here is an example of a GitHub Actions workflow that runs the benchmarks and
reports the results to CodSpeed on every push to the `main` branch and every
pull request:

<CIWorkflow
  mode="simulation"
  buildSteps={[
"- name: Set up Bazel",
"  uses: bazelbuild/setup-bazelisk@v2",
"- name: Build the benchmark target",

"  run: |",
"    bazel build //path/to/bench:my_benchmark --@codspeed_cpp//core:codspeed_mode=simulation",

]}
  benchmarkCommand={[ "|", "bazel run //path/to/bench:my_benchmark\
--@codspeed_cpp//core:codspeed_mode=simulation", ]}
/>

<Info>
  **Separated build and run steps**

  Note that we separated the build and run steps in the CI workflow. This is
  important to speed up the CI workflow and avoiding instrumenting the build step.
</Info>

### Custom build systems

If you need to have full control over your build system, here are guiding steps
to take to use codspeed.

#### Get the sources

Sources are located in the
[`codspeed-cpp`](https://github.com/CodSpeedHQ/codspeed-cpp) repository. You can
either clone the repository, add it as a submodule or even download the sources
as a zip file.

#### Build the library

Sources of the `google_benchmark` CodSpeed integration library are located in
the
[`google_benchmark` subdirectory](https://github.com/CodSpeedHQ/codspeed-cpp/tree/main/google_benchmark). 3.
Make sure the following pre-processor variables are defined when you build the
library

When building the library, the tricky part is to make sure google\_benchmark's
fork has access to the
[`codspeed-core`](https://github.com/CodSpeedHQ/codspeed-cpp/tree/main/core)
library.

Additionally, the following pre-processor variables must be defined:

* `CODPSEED_ENABLED`: if not defined, `google_benchmark` will the same as the
  upstream library, with no CodSpeed features.
* `CODSPEED_SIMULATION`: if running in simulation mode
  * Note: For versions prior to v2.0.0, use `CODSPEED_INSTRUMENTATION` instead.
* `CODSPEED_WALLTIME`: if running in walltime mode
* `CODSPEED_ROOT_DIR`: absolute path to the root directory of your project. This
  is used in the report to display file path relative to your root project

If you run into issues integrating CodSpeed's `google_benchmark` library with
your project, please reach out and open an issue on the
[codspeed-cpp](https://github.com/CodSpeedHQ/codspeed-cpp) repository.

