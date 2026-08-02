# C++98 to C++17 and the actor model: the minimum on-ramp

Type: research
Status: resolved
Blocked by: —

## Question

The developer has written a lot of C++98 and has never used move semantics. The
subject requires C++17 and an actor-based architecture. Find the shortest path
that closes that gap — *shortest*, because this is a means to CrashLab, not a
C++ course, and time spent here is time not spent on finance.

**What the gap actually contains, given a C++98 starting point:**

- **Move semantics and rvalue references** — the single largest conceptual jump.
  Why they exist, `std::move`, what the compiler does without them, and the rule
  of zero/three/five as it now stands.
- **Smart pointers and ownership** — `unique_ptr`, `shared_ptr`, and why raw
  `new`/`delete` largely disappears. A C++98 developer already understands
  ownership; the syntax is new, the concept is not.
- **`auto`, range-for, uniform initialisation, `nullptr`, `constexpr`,
  `enum class`** — the small ergonomic changes that make modern code
  unrecognisable to a C++98 reader.
- **`std::chrono`** — the subject timestamps everything in nanoseconds and
  demands an abstract clock (real time in live, simulated time in replay).
- **C++17 specifically** — structured bindings, `std::optional`, `std::variant`,
  `string_view`, `if constexpr`. Which of these will actually be used here?
- **Templates as written today** — enough to read library code, not enough to
  write a metaprogramming library.
- **The actor model itself** — message passing, no shared mutable state, why
  this eliminates locks, mailboxes, supervision. This is a *concept* to learn
  before touching Simplx's particular expression of it. Erlang/Akka literature
  may teach it better than any C++ source.
- **Determinism under concurrency** — why the subject can demand that the same
  seed produce the same functional hash, and what that forbids (wall-clock
  reads, unordered iteration, address-dependent behaviour, thread-scheduling
  dependence).
- **CMake** — the developer knows Make well. Find the shortest bridge, not an
  introduction to build systems.

**Also cover the critical-path constraint**: the subject forbids disk, network,
console output and global mutexes inside matching handlers, and requires
allocations after warm-up to be measured and justified. Find what a developer
needs to understand about allocation, cache behaviour and lock-free thinking to
honour that — at the level of "why this rule exists", not "how to write a
lock-free queue".

**Selection criteria**: prefer sources that address *experienced C++
programmers updating their knowledge* rather than beginners — that audience is
well served and the material is far shorter. Name specific chapters or talks.
Say what to skip.

## Answer format

An ordered on-ramp with rough time cost, split into **before M2** and **learn in
place while building**. Explicitly identify anything that can be skipped
entirely for this project.

## Answer

Resolved. Full deliverable: `../research/06-cpp17-and-actors.md` (765 lines).

**The on-ramp is ~21.5 h before Exchange A, ~6.5 h learned in place, and every
pre-M2 source is free.** Path: Stroustrup's C++11 FAQ as a delta document →
Iglberger's move-semantics talks → O'Dwyer on RAII and smart pointers → ~20
named Core Guidelines rules → Armstrong's thesis (~25 pages of 295, for the
actor model as a concept) plus Akka's guide → LMAX Disruptor and Will Wilson on
determinism → Carl Cook on the critical path → a four-step CMake bridge → then
read `actor.h` and `engine.h` as documents.

**The agent read the vendored Simplx source before choosing any reading, and
that reshaped the answer.** Verified independently against the source:

- **`Pipe::push` does not perfect-forward.** `include/trz/engine/actor.h:2735`
  takes `_Args&&...` but calls `newEvent<_Event>(chain, args...)` with no
  `std::forward`; `EventWrapper` repeats the mistake at line 2801. Arguments are
  copied at the event boundary, so **move semantics buys nothing there** — which
  removes perfect forwarding (Meyers Items 24–28, 30) from the syllabus
  entirely. (Note: the deliverable cites this header as `include/trz/actor.h`;
  the real path is `include/trz/engine/actor.h`. Line numbers are correct.)
- **Event destructors are never called.** Events are bump-allocated into
  recycled `EventAllocatorPage`s; the only explicit destructor call anywhere in
  `src/` is `src/engine/node.cpp:447`'s `tmp->~EventTable()`. Nothing
  `static_assert`s against it, and **tutorials 03/04/08 put `std::string` in
  events — those leak** for any non-SSO string. Event payloads must be trivially
  destructible POD. This happens to align exactly with the subject's ban on
  binary floats in the ledger and its scaled-integer requirement.
- **One pinned OS thread per core, run-to-completion handlers, no shared state.**
  The subject's "no global mutex in matching handlers" is therefore satisfied by
  construction, which makes the C++ memory model, `std::atomic`, mutexes and
  lock-free data structures all **skippable**.
- **`TimerProxy` is wall-clock driven** — a determinism hazard. Funding and
  liquidation ticks must be scenario events on the simulated clock, never timers.
- **No supervision tree**, so Erlang/OTP supervisor material is background only.
- **`include/trz/pattern/bus/ringbuffer.hpp`** (verified present, 8.5 KB) is an
  SPSC ring buffer with explicit cache-line padding — the sanctioned escape
  hatch for disk, network and oracle I/O, and the best false-sharing lesson
  available in the tree.

**Skip list** covers ~20 items in five categories: all of C++20/23, perfect
forwarding, threading primitives, lock-free implementation, `std::variant`, the
822-page templates book, Hewitt 1973, and learning Erlang itself.

**Seven uncertainties flagged honestly** in §7, including two CppCon 2019 talks
verified by track listing but not video URL, and `stroustrup.com/Tour2_toc.pdf`
returning 404 so the *Tour* chapter list is explicitly **not** verified.

**Two findings handed onward:** the C++11/C++17 flag question (§1.5) goes to
ticket 01; the cross-core event-ordering determinism question becomes ticket 14.
