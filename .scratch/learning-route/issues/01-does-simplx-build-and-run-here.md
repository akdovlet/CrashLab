# Does Simplx build and run here?

Type: task
Status: closed — **usable with patches**
Blocked by: —
Deliverable: [`research/01-simplx-build-and-run.md`](../research/01-simplx-build-and-run.md)
             + [`research/01-simplx-cpp17.patch`](../research/01-simplx-cpp17.patch)

## Question

Exchange A is worth 13 points and is the entire actor-model learning surface, and
it is built on Tredzone Simplx. Before any route can be sequenced, we need to
know whether Simplx is a working foundation or a liability.

The known risks, all verified facts:

- Last upstream commit is `ff9d5bf`, **3 September 2019** — roughly seven years
  unmaintained.
- `vendor/simplx/common_simplx.cmake:19` sets `--std=c++11`, while the subject
  requires C++17.
- The local toolchain is **GCC 13.3** / CMake 3.28.3. GCC 13 tightened
  transitive includes; code of this vintage commonly fails with missing
  `<cstdint>`, `<algorithm>`, `<stdexcept>`.
- `vendor/simplx/build/` does not exist — `scripts/setup.sh` either skipped the
  Simplx step or hit its documented failure path and carried on.

**Resolve by actually doing it**, not by reading about it:

1. Configure and build Simplx verbosely. Record every patch needed (the setup
   script suggests `-DCMAKE_CXX_FLAGS='-include cstdint'` as a starting point).
2. Build and **run** at least one thing from `vendor/simplx/tutorial/` — a
   framework that compiles but deadlocks is not a working foundation.
3. Try forcing `-std=c++17` and record what breaks. The subject demands C++17;
   if Simplx only tolerates C++11, that tension has to be named now.
4. Run its test suite if one exists under `vendor/simplx/test/`.
5. Skim the actor API — `vendor/simplx/include/` — and judge: is the event /
   actor / pipe model something a C++98 developer can learn from, or is it
   idiosyncratic enough to teach bad habits?

## Answer format

Record: the exact patch set needed to build, whether tutorials run, the C++17
verdict, and a one-line judgement — **usable as-is / usable with patches /
liability**. If the verdict is "liability", say what the alternative shape of
Exchange A would be, because that changes the whole route.

---

## Added by ticket 06 (C++17 and actor on-ramp), which read the source

Three findings that this ticket should verify empirically while it has the build
in front of it:

1. **`common_simplx.cmake` appends `--std=c++11` unconditionally**, *before* the
   check that is supposed to detect a user override, and *after* the user's own
   flags — so the override logic looks broken. GCC 13.3 already defaults to
   C++17, which means the framework may currently be forcing a *downgrade*.
   Establish what standard the build actually uses, and whether forcing C++17
   works. (`throw()` is not the obstacle it might appear: it is legal in C++17
   and only removed in C++20, and non-empty dynamic exception specifications
   appear only in comments.)
2. **Event payloads must be trivially destructible POD** — destructors are never
   run on events. Confirm by putting a long `std::string` in an event and
   watching under Valgrind, which is already installed. Note that tutorials
   03/04/08 do exactly this, so they are expected to leak; that is a useful
   thing to observe deliberately rather than discover later.
3. **`TimerProxy` is wall-clock driven.** Confirm, because if so, no funding or
   liquidation tick may ever be scheduled on a Simplx timer in replay mode.

---

## Answer (2026-08-03) — **usable with patches**

Full record: [`research/01-simplx-build-and-run.md`](../research/01-simplx-build-and-run.md).
Patch set as a diff: [`research/01-simplx-cpp17.patch`](../research/01-simplx-cpp17.patch).
Everything below was executed on GCC 13.3 / CMake 3.28.3 / Valgrind 3.22.

**Patch set — 5 files, +23/−7, no algorithmic change**, and the tree still builds
at C++11 afterwards:

1. `src/engine/linux/platform_linux.cpp` — `unique_ptr<FILE, decltype(&pclose)>`
   → named deleter class. `-Werror=ignored-attributes` under GCC 13. **This alone
   blocked the C++11 build too**, which is why `vendor/simplx/build/` never
   existed. The setup script's `-include cstdint` hint is not needed — there are
   no missing-include failures at all.
2. `include/trz/engine/actor.h` — restore the commented-out `noexcept` on the
   `registerCallback` / `registerPerformanceNeutralCallback` parameters (C++17
   P0012R1: `noexcept` is part of the type; the `.cpp` and the
   `Callback::onCallback` member already have it).
3. `include/trz/engine/actor.h` — drop `throw()` from `breakThrow`. **Latent
   runtime bug, not just a port issue**: `throw()` terminates on throw in C++11
   as well, so every `breakThrow(std::bad_alloc())` in the event allocator was
   aborting the process. A second bug is left in place deliberately — `throw e;`
   on a `const std::exception&` **slices**, so `catch (std::bad_alloc&)` can never
   fire. Needs a decision if CrashLab relies on allocator back-pressure.
4. `include/trz/engine/internal/time.h` — `DateTime(const DateTime&) = default`
   (`-Werror=deprecated-copy`). **Blocks the timer and everything scheduled.**
5. Two vacuous `assert(unsigned >= 0)` in the TCP circular buffer; one stale
   `#include "trz/util/timer.h"` in the HTTP connector — **that header does not
   exist anywhere in the repo**, so the HTTP server is unbuildable as published.

Not a source patch: googletest is an empty submodule dir and `vendor/simplx` is
vendored, not a submodule — cloned v1.14.0 by hand, ignored in `.gitignore`, and
configured with `-DGOOGLETEST_VERSION=1.14.0` (Simplx adds googletest's *inner*
directory, which expects that variable from its own parent).

**Tutorials run.** 13/13 targets build; every non-interactive one exits 0,
including 08_pingpong's real core-1 → core-2 → core-1 round trip and 10_timer's
three 1-second ticks. 11_keyboard_actor spins on EOF because it is a keyboard
reader. No deadlocks. **Unit tests: 12/12 in `test/engine`, 2/2 in
`test/connector/tcp`**, all at C++17.

**C++17 verdict: works, but the framework cannot select it.** Finding 1 confirmed
and worse than described — `--std=c++11` is appended *after* the user's flags, and
GCC takes the last `-std`. So `-DCMAKE_CXX_FLAGS="-std=c++17"` is **silently
ignored** (verified: `__cplusplus` = 201103L); only `-DCMAKE_CXX_STANDARD=17`
works, because CMake emits its standard flag last. Simplx is currently forcing a
*downgrade* from GCC 13.3's own C++17 default. `throw()` was indeed not an
obstacle — but not for the stated reason: it is legal in C++17 yet *means*
`noexcept`, which is exactly what broke `breakThrow`. 14 `throw()` sites remain,
so **C++20 is out** without more work.

**Finding 2 confirmed, and it hides at small sizes.** `~Event()` is empty and
non-virtual, events are bump-allocated in place, destructors never run, nothing
asserts it. Tutorial 03 under Valgrind unmodified: **0 bytes leaked** — a false
all-clear, because `"Hello, World!"` fits in the SSO buffer. Lengthen the literal
past 15 chars and it is `172 bytes definitely lost in 2 blocks`, one per event.
A short `std::string` in an event passes every test, then leaks in production the
moment an order ID gets long. The assertion cannot be written on the event type
(`Actor::Event` has a user-provided destructor) — assert on the payload members.

**Finding 3 confirmed.** `TimerActor::onCallback()` → `timeGetEpoch()` →
`gettimeofday()` → `CLOCK_REALTIME`. Not monotonic, not injectable. **But there is
a designed seam for ticket 14**: that method is `virtual`, and the clock-taking
overload `onCallback(const DateTime&)` is `protected`, commented *"protected for
unit testing override"*. Overriding it replaces the clock without patching the
framework — though the engine still calls it once per loop iteration, so tick
*placement* remains loop-dependent.

**Two things nobody had flagged:**

- **The engine busy-spins one core at 100%** (tutorial 10 idling: 99% CPU, 7.9 s
  user time over 7.9 s wall). Correct for a low-latency exchange, but *N* cores =
  *N* cores pegged, and **wall-clock benchmarking is meaningless** — throughput is
  bounded by loop iterations, not work. The repo's `benches/` + CodSpeed setup
  needs to measure bounded event batches, not a running engine. Worth settling
  before the benchmark milestone designs itself around a wrong number.
- **`trz_add_topdir` compiles every TU twice** (`SOURCE_FILES ... PARENT_SCOPE`
  leaks both ways) and drags `-Werror -Wpedantic` plus the `--std=c++11` override
  into the consumer. CrashLab should name the nine engine sources directly —
  recipe in §6 of the deliverable, built and run Valgrind-clean.

**API judgement: teaches good habits.** Four nouns — `Actor`, `Event`, `Pipe`,
`Service` — no threads, mutexes, atomics or shared state anywhere in the user's
reach, so the framework structurally prevents the concurrency mistakes a C++98
developer is likeliest to make. Ticket 06's syllabus cut is confirmed by the
source. Two edges to name explicitly: the event-POD rule runs against everything
else modern C++ teaches about RAII (teach events as wire format, not objects),
and the exception style — `throw()`, slicing, `// throws (...)` in comments — is
to be read, not imitated.
