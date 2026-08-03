# Simplx: does it build and run here?

Answers ticket [`01-does-simplx-build-and-run-here.md`](../issues/01-does-simplx-build-and-run-here.md).
Everything below was executed on this machine on **2026-08-03**, not read about.

**Verdict: usable with patches.** Five files, +23/−7 lines, no algorithmic change.
All 13 tutorial targets build and run at C++17; 14/14 unit tests pass; a fresh
C++17 consumer project links the engine and runs two actors on two cores with a
repeating timer, Valgrind-clean.

- Toolchain: GCC 13.3.0, CMake 3.28.3, Valgrind 3.22.0, 8 cores, Linux 7.0.0-28.
- Patch set as a diff: [`01-simplx-cpp17.patch`](01-simplx-cpp17.patch)

---

## 1. The patch set

Applied to `vendor/simplx/`. Each is a portability fix; each keeps the C++11
build working (verified: tutorial 08 rebuilt and ran under the default C++11
configuration after patching).

### 1.1 `src/engine/linux/platform_linux.cpp` — GCC 13 blocks the build entirely

```
error: ignoring attributes on template argument 'int (*)(FILE*)' [-Werror=ignored-attributes]
```

`unique_ptr<FILE, decltype(&pclose)>` — glibc decorates `pclose` with function
attributes that GCC 13 refuses to carry into a template argument. Replaced with a
named deleter class. **This one error alone stops the C++11 build too**, which is
why `vendor/simplx/build/` never existed.

The setup script's suggested `-DCMAKE_CXX_FLAGS='-include cstdint'` is not needed —
there are no missing-include failures at all. `-Wno-ignored-attributes` also works
as a flag-only workaround, but the source fix keeps `-Werror` meaningful.

### 1.2 `include/trz/engine/actor.h` — two C++17 breaks

**`registerCallback` / `registerPerformanceNeutralCallback`.** C++17 P0012R1 made
`noexcept` part of the function type. The header declared the callback parameter
with `noexcept` *commented out*:

```cpp
void registerCallback(void (*onCallback)(Callback &) /*noexcept*/, Callback &) noexcept;
```

while `actor.cpp:695`/`:706` define it *with* `noexcept`, and the `Callback::onCallback`
member at `actor.h:836` is itself a `noexcept` pointer. Under C++11 these are the
same type; under C++17 they are three different types and the definitions match no
declaration. Fix: uncomment — restoring `noexcept` is consistent with both the
definition and the member.

**`breakThrow`.** Declared `inline void breakThrow(const std::exception &e) throw()`
and its body is `throw e;`. C++17 P0003R5 made `throw()` mean `noexcept`, so GCC
fails with `-Werror=terminate`. Fix: drop the exception specification.

> **This was a latent runtime bug, not merely a port issue.** `throw()` calls
> `terminate()` on throw in C++11 as well. Every `breakThrow` call site —
> including `node.cpp:1282` and `:1301`, which pass `std::bad_alloc()` from the
> event allocator and clearly expect an exception to propagate — was aborting the
> process instead. A second, unfixed bug lives in the same function: `throw e;`
> on a `const std::exception&` **slices**, so even once it throws, a
> `catch (std::bad_alloc &)` upstream will never fire. Left alone deliberately —
> it is pre-existing behaviour identical in both standards, and worth a separate
> decision. **If CrashLab is to rely on event-allocator back-pressure, this needs
> revisiting.**

### 1.3 `include/trz/engine/internal/time.h` — `DateTime` (blocks the timer)

`DateTime` has a user-provided `operator=` and no copy constructor, so GCC 13
deprecates the implicit one (`-Werror=deprecated-copy`). Fix: `DateTime(const
DateTime &) noexcept = default;`. Its base `Time` already declares one, which is
why only `DateTime` trips. **Blocks tutorial 10 and everything using
`timer::TimeOutEvent`**, i.e. all scheduled work.

### 1.4 `include/trz/connector/tcp/client/circularbuffer.hpp` — two vacuous asserts

`assert(m_writerIndex >= 0)` / `assert(m_readerIndex >= 0)` on `size_t` →
`-Werror=type-limits`. Deleted; they assert nothing.

### 1.5 `include/trz/connector/http/server/serverprocess.hpp` — a header that does not exist

`#include "trz/util/timer.h"` — **`trz/util/` is nowhere in the repository.** The
HTTP connector cannot be built as published. Nothing in the file uses a timer
symbol, so the include is stale; commented out and the sample builds. Relevant
only if CrashLab ever wants Simplx's own HTTP server, which it almost certainly
should not — Exchange B's REST/WS layer is Python.

### 1.6 Not a source patch: googletest

`thirdparty/googletest/` is an empty submodule directory and `vendor/simplx` is
vendored into CrashLab, not a submodule, so `git submodule update` is not
available. Cloned v1.14.0 manually; added `vendor/simplx/thirdparty/` to the
CrashLab `.gitignore`.

Simplx does `trz_add_topdir(thirdparty/googletest/googletest)` — the *inner*
directory — so `GOOGLETEST_VERSION`, which googletest ≥ 1.10 expects from its own
parent, is undefined and configuration fails. Pass `-DGOOGLETEST_VERSION=1.14.0`;
no file needs patching.

---

## 2. The C++17 verdict

**C++17 works, and the framework's own build system cannot select it.**

`common_simplx.cmake:19` appends `--std=c++11` to `CMAKE_CXX_FLAGS` **before** the
check that is supposed to detect a user override — so the check at line 22 always
finds the string it just wrote, and the `else` branch is dead. Ticket 06 read this
correctly. Worse, the append lands *after* the user's own flags, and GCC takes the
last `-std` on the line:

| invocation | resulting flags | effective standard |
|---|---|---|
| default | `--std=c++11 …` | C++11 |
| `-DCMAKE_CXX_FLAGS="-std=c++17"` | `-std=c++17 --std=c++11 …` | **C++11** — silently ignored |
| `-DCMAKE_CXX_STANDARD=17` | `--std=c++11 … -std=gnu++17` | **C++17** |

Verified directly (`g++ -dM -E` reports `__cplusplus 201703L` and `201103L`
respectively). So the framework **is currently forcing a downgrade** from GCC
13.3's own C++17 default, and the obvious way to ask for C++17 fails silently.
`CMAKE_CXX_STANDARD` wins only because CMake emits the standard flag last.

Once the patches are in, C++17 costs nothing further: 13/13 tutorial targets and
14/14 tests build and pass at `-DCMAKE_CXX_STANDARD=17`, and the same tree still
builds at C++11.

Ticket 06 was right that `throw()` is not the obstacle it looks like — but for a
narrower reason than "legal in C++17". It is legal, but `throw()` *means*
`noexcept` in C++17, which is exactly what broke `breakThrow`. There are 13
`throw()` spellings left in the headers and one in the tutorials
(`10_timer`: `void onTimeout(const DateTime&) throw() override`).

> **C++20 is not available.** `throw()` was removed in C++20. `-std=c++20` would
> require touching all 14 sites. CrashLab needs C++17 and the subject requires
> C++17, so this is a note, not a problem — but do not casually bump the standard
> later.

Confirmed by writing `noexcept override` instead of `throw() override` in the
integration probe: the modern spelling works, so **CrashLab code need never write
`throw()`**, only read it in framework headers.

---

## 3. Do the tutorials actually run?

All 13 built targets run; every non-interactive one exits 0. Not a deadlock in sight.

| tutorial | result |
|---|---|
| 01 hello_actor, 02 hello_world | exit 0 |
| 03 printer_actor_starter | exit 0, both writer actors delivered |
| 04 printer_actor_service, 05 multi_callback | exit 0 |
| 06 undelivered_event_management | exit 0, all three undelivered handlers fired |
| 07 referenced_unreferenced_actor | exit 0 |
| 08 pingpong | exit 0 — **real cross-core round trip**, core 1 → core 2 → core 1 |
| 09 sync_exit | exit 0 |
| 10 timer | 3 ticks at 1 s, self-destructs, exit 0 |
| 11 keyboard_actor | spins on EOF (it is a keyboard reader; ran it with `</dev/null`) — not a framework fault |
| 12 tcp/http samples | build and start; not exercised, they need a network peer |
| 13 cross_thread_bus | plain Makefile, no CMake — not built |

Unit tests, `-DCMAKE_CXX_STANDARD=17`:

- `test/engine` — **12/12 passed**, 12.05 s (incl. `testtimer`, `testparallel`, `testasyncengine`)
- `test/connector/tcp` — **2/2 passed**

---

## 4. Three findings ticket 06 asked to verify

### 4.1 Event payloads must be trivially destructible POD — **CONFIRMED, and it leaks silently**

`Actor::Event`'s destructor (`actor.h:2254`) is `inline ~Event() noexcept {}` —
non-virtual, empty. Events are bump-allocated in place in an event page and the
destructor is **never** run. There is no `static_assert` guarding this.

Tutorial 03 puts a `const std::string` in `PrintEvent`. Under Valgrind, unmodified:
**0 bytes leaked**. That is a false all-clear — `"Hello, World!"` is 13 characters
and fits in libstdc++'s small-string buffer, so it never touches the heap.

Re-run with the literal lengthened past the SSO threshold:

```
86 bytes in 1 blocks are definitely lost
  by PrintEvent::PrintEvent(std::string const&)
  by Actor::Event::Pipe::EventWrapper<PrintEvent>::EventWrapper<char const(&)[86]>
  ...
LEAK SUMMARY: definitely lost: 172 bytes in 2 blocks
```

One leak per event sent, forever, in a system designed to send millions.

> **This is the single sharpest edge in the framework, and it is invisible at
> small sizes.** A `std::string` under 16 characters in an event will pass every
> test and every Valgrind run, then leak in production the moment a symbol name or
> client order ID gets long. The route should teach a hard rule — **no owning
> types in events, ever** — and CrashLab should carry a `static_assert` on payload
> members rather than trust discipline. It aligns with the subject's scaled-integer
> requirement, so nothing is lost.
>
> Note the assertion cannot be written on the event type: `Actor::Event` has a
> user-provided destructor, so `is_trivially_destructible_v<MyEvent>` is `false`
> by construction. Assert on the members.

### 4.2 `TimerProxy` is wall-clock driven — **CONFIRMED**

`TimerActor::onCallback()` (`src/pattern/timer/timeractor.cpp:47`) calls
`timeGetEpoch()`, which is `gettimeofday()` — `CLOCK_REALTIME`
(`include/trz/engine/internal/linux/platform_gcc.h:268`). Not monotonic, not
injectable, and subject to NTP steps.

Ticket 06's conclusion stands: **no funding or liquidation tick may be scheduled
on a Simplx timer in replay mode.**

There is, however, a designed escape hatch — hand this to ticket 14:
`TimerActor::onCallback()` is `virtual` (private virtual is still overridable),
and the clock-taking overload `onCallback(const DateTime&)` is `protected`, with
the comment *"protected for unit testing override"*. A `ReplayTimerActor :
TimerActor` overriding the nullary form to call the `DateTime` form with
simulation time is the intended seam. It does not make the engine deterministic
by itself — the engine still calls the callback once per event-loop iteration, so
*when* a tick lands still depends on loop scheduling — but the clock source is
replaceable without patching the framework.

### 4.3 `common_simplx.cmake` override logic is broken — **CONFIRMED**, see §2.

---

## 5. Two things nobody had flagged

### 5.1 The engine busy-spins one core at 100%

Tutorial 10, doing nothing but a 1-second timer for 8 seconds:

```
User time (seconds): 7.90
Percent of CPU this job got: 99%
```

Simplx is a run-to-completion, pinned-thread, spin-loop engine — no blocking, no
sleeping. This is the correct design for a low-latency exchange and it is why
Euronext uses it, but the practical consequences for CrashLab are immediate:

- *N* cores in the start sequence = *N* cores pegged at 100%, on a laptop too.
- **Wall-clock benchmarking is meaningless** — throughput is bounded by loop
  iterations, not by work done. The repo already has `benches/` and a CodSpeed
  workflow; instruction-count measurement will count spin iterations unless
  benchmarks measure a bounded batch of events rather than a running engine. Worth
  raising before the benchmark milestone designs itself around a wrong number.
- Tests that start an engine must tear it down; CI with several concurrent Simplx
  tests will saturate the runner.

### 5.2 `trz_add_topdir` compiles everything twice — do not use it

`src/engine/CMakeLists.txt` ends with `set(SOURCE_FILES ${SOURCE_FILES}
PARENT_SCOPE)`, and `SOURCE_FILES` is inherited *into* the engine directory from
whoever included it. So the tutorial's own `.cpp` is appended to the engine
library's source list, and the engine's sources are appended to the tutorial's.
Tutorial 01 really does produce both:

```
engine.dir/actor.cpp.o                 hello_actor.bin.dir/…/src/engine/actor.cpp.o
engine.dir/…/hello_actor.cpp.o         hello_actor.bin.dir/hello_actor.cpp.o
```

Every translation unit compiled twice, tutorial source linked into the library.
It works, but it is not a pattern to copy — and it also drags `-Werror -Wpedantic`
and the `--std=c++11` override into the consumer.

---

## 6. Integration recipe for CrashLab

Do **not** `include(common_simplx.cmake)`. Name the nine engine sources directly.
This was built and run, not sketched:

```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(simplx STATIC
    ${SIMPLX_DIR}/src/engine/actor.cpp
    ${SIMPLX_DIR}/src/engine/engine.cpp
    ${SIMPLX_DIR}/src/engine/node.cpp
    ${SIMPLX_DIR}/src/engine/RefMapper.cpp
    ${SIMPLX_DIR}/src/engine/linux/platform_gcc.cpp
    ${SIMPLX_DIR}/src/engine/linux/platform_linux.cpp
    ${SIMPLX_DIR}/src/engine/parallel/parallel_xplat.cpp
    ${SIMPLX_DIR}/src/engine/e2e_stub.cpp
    ${SIMPLX_DIR}/src/pattern/timer/timeractor.cpp
)
target_include_directories(simplx PUBLIC ${SIMPLX_DIR}/include)
target_compile_definitions(simplx PUBLIC TREDZONE_E2E=0)   # required; the cmake macro normally supplies it
find_package(Threads REQUIRED)
target_link_libraries(simplx PUBLIC Threads::Threads)
```

The consumer then gets its own warning flags, its own standard, and no double
compilation. The probe (`scratchpad/integration/probe.cpp`) exercised structured
bindings, `if`-with-initialiser and `string_view` in the consuming TU, a POD
`QuoteEvent` sent from a timer-driven actor on core 0 to a service actor on core
1, and a clean shutdown: Valgrind `ERROR SUMMARY: 0 errors`, no leaks.

---

## 7. Is the API something a C++98 developer can learn from?

**Yes — it teaches good habits, with two sharp edges to teach explicitly.**

The public surface is small (≈17.8k lines of headers, ≈4.5k of implementation,
six public headers) and the vocabulary is four nouns: `Actor`, `Event`, `Pipe`,
`Service`. The whole of tutorial 08:

```cpp
struct TravelLogEvent : Actor::Event { TravelLogEvent(const string &p) : visited(p) {} string visited; };

class PongActor : public Actor {
public:
    PongActor() { registerEventHandler<TravelLogEvent>(*this); }
    void onEvent(const TravelLogEvent &e) {
        Event::Pipe pipe(*this, e.getSourceActorId());
        pipe.push<TravelLogEvent>(e.visited + ", visited Pong @ core #" + to_string((int)getCore()));
    }
};

Engine::StartSequence seq;
seq.addServiceActor<PongTag, PongActor>(2);   // core 2
seq.addActor<PingActor>(1);                   // core 1
Engine engine(seq);
```

There is no `std::thread`, no mutex, no atomic, no shared state — the framework
*structurally prevents* the concurrency mistakes a C++98 developer is most likely
to make, which is the best possible property for this project. Ticket 06's
syllabus cut (no perfect forwarding, no lock-free work) is confirmed by the
source. The messaging model — typed events, tag-dispatched services, one handler
per event type — is close enough to Akka/Erlang/Orleans that the concepts
transfer.

**Two things it will teach wrong if not called out:**

1. **The event-destructor rule (§4.1) is idiosyncratic and unenforced.** It runs
   against everything else modern C++ teaches about RAII. Teach it as "events are
   wire format, not objects".
2. **The exception style is dated.** `throw()` specifications, `breakThrow`
   swallowing the exception type by slicing, and `// throws (std::bad_alloc,
   ShutdownException)` written as comments. Read it, do not imitate it.

Minor, non-blocking: `Time`/`DateTime` predate `std::chrono` and there is no
`<chrono>` interop; unmaintained since Sept 2019 with no upstream to report to;
Linux/GCC/Clang only.

---

## 8. What this means for the route

The contingency in map.md — *"How the route handles a Simplx failure"* — **does
not fire.** Exchange A keeps its planned shape. Simplx is a working foundation on
this machine at C++17, with a 30-line patch set that should be committed once and
never thought about again.

What does change:

- **The patch set is itself a route artefact.** Diagnosing five distinct
  portability failures across three language-standard changes (P0012R1, P0003R5,
  `-Wdeprecated-copy`) is a real modern-C++ lesson, and it is already done — it
  should be *read*, not repeated.
- **`-DCMAKE_CXX_STANDARD=17`, never `CMAKE_CXX_FLAGS`.** A silent downgrade to
  C++11 would be a miserable thing to discover at M6.
- **Ticket 14 (determinism) has its seam**: override `TimerActor::onCallback()`.
  It does not solve loop-ordering determinism.
- **Benchmarking needs rethinking before it starts** — see §5.1.
- **The event-POD rule should appear in the route as a first-day constraint**, not
  as a footnote discovered by Valgrind at M5.
