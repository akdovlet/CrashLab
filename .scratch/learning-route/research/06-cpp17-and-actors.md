# C++98 → C++17 and the actor model: the minimum on-ramp

Resolves issue `06-cpp98-to-cpp17-and-actors.md`.
Researched 2026-08-02. Sources verified individually; anything I could not verify is
flagged as such in the "Honest uncertainties" section at the bottom — **do not treat an
unflagged citation and a flagged one as equally solid.**

Reader profile assumed throughout: **a lot of C++98 written, never used move semantics,
knows Make well, comfortable learning CMake.** Pointers, ownership, RAII-in-spirit and UB
are already understood. Everything below is the *delta* only.

---

## 0. The headline

**The gap is much smaller than it looks, and it is smaller still because of what Simplx
actually is.**

I read the vendored framework (`/home/ak/CrashLab/vendor/simplx`) before choosing sources,
and it changes the recommendation materially:

- Simplx is a **C++11-era codebase, last upstream commit 2019-09-03** (`ff9d5bf`). Its
  public API takes everything by `const&`, its "smart pointer" is an `auto_ptr`-style
  move-through-copy class, and its event constructor path **does not perfect-forward**.
- Its events are **bump-allocated into recycled pages and their destructors are never
  called**, so your hot-path types must be trivially destructible POD. Move semantics buys
  you *nothing* at the Simplx event boundary.
- Its threading model — one pinned OS thread per core, run-to-completion handlers, no
  shared mutable state — **satisfies the subject's "no global mutex on the critical path"
  rule by construction**. You do not need the C++ memory model for this project.

So: learn move semantics **properly but once** (it is the largest conceptual jump and you
cannot read modern library code without it), learn the actor model **as a concept** (2–3
hours of Erlang literature beats any C++ source), and skip an enormous amount of
well-marketed material listed in §5.

**Total pre-M2 budget: ~20 focused hours.** Everything else is learned in place.

---

## 1. What Simplx actually is (findings from reading the vendored source)

This section exists because it determines what C++ you need. Every claim here is from
reading files under `/home/ak/CrashLab/vendor/simplx`; file and line references are given
so they can be re-checked. **Ticket 01 owns building it — nothing here is a build
instruction.**

### 1.1 The model in one paragraph

An `Engine` is constructed from a `StartSequence` which names, per CPU core, the actor
classes to instantiate (`include/trz/engine/engine.h:639`, `:655`). The engine starts
**one OS thread per `CoreId`** (`src/engine/engine.cpp:530`, `AsyncNode::Thread`), pins it,
and runs a cooperative event loop on it (`EngineEventLoop`,
`include/trz/engine/engine.h:94`). Actors on the same core are scheduled by that single
loop; **handlers run to completion**. Actors never touch each other's state; they send
typed events through a `Pipe`.

### 1.2 The five API facts you need before writing a line

| Concept | API | Tutorial |
|---|---|---|
| Define an actor | `class X : public Actor` | `tutorial/01_hello_actor` |
| Define an event | `struct E : Actor::Event { … }` | `tutorial/03_printer_actor_starter` |
| Receive | `registerEventHandler<E>(*this);` + `void onEvent(const E&)` | 03 |
| Send | `Event::Pipe pipe(*this, destId); pipe.push<E>(args…);` | 03 |
| Find a peer | `struct Tag : Service {};` + `addServiceActor<Tag,X>(core)` + `getEngine().getServiceIndex().getServiceActorId<Tag>()` | `tutorial/04`, `tutorial/08` |

That is the whole surface for M2's nine actors. `Pipe` is unidirectional; a reply needs a
second pipe built from `event.getSourceActorId()` (`tutorial/08_pingpong`).

### 1.3 The gotchas that will cost you a day each if nobody tells you

**(a) Event destructors are never called.** Events are bump-allocated into pre-allocated,
recycled `EventAllocatorPage`s (`src/engine/node.cpp:271–283`). The only explicit
destructor call anywhere in `src/` is `tmp->~EventTable()` (`src/engine/node.cpp:447`) —
there is no per-event destructor invocation, and **no `static_assert` guarding it**
(grepped `include/trz/engine/actor.h`: no `is_trivially_*` anywhere). `Actor::Event`'s own
destructor is `inline ~Event() noexcept {}` (`actor.h:2250`).

Consequence: **an event holding a `std::string` or `std::vector` leaks its heap buffer.**
Tutorials 03, 04 and 08 all do exactly this (`const string message;`,
`string visited;`) — they survive only because of small-string optimisation. Simplx's own
doc says the quiet part out loud: *"typename **struct** for Event types as they're often
Plain Old Data (POD)"* (`doc/index.dox`, coding-conventions section).

For CrashLab this is a **free win**, not a constraint: the subject already forbids binary
floats in the ledger and demands scaled integers or explicit decimals. Fixed-size POD
events with `int64_t` scaled price/qty and fixed `char[]` symbols satisfy both rules at
once, and make the "no allocation after warm-up" requirement nearly automatic.

**(b) `Pipe::push` does not perfect-forward.** The signature looks modern:

```cpp
template<class _Event, class... _Args> inline _Event& push(_Args&&...args) {   // actor.h:2735
    _Event* ret = newEvent<_Event>(destinationEventChain, args...);            // no std::forward
```

and the wrapper that finally constructs it does `_Event(args...)`, not
`_Event(std::forward<Args>(args)...)` (`actor.h:2800`). Arguments are **copied** into the
event. You cannot move into an event. Likewise `addActor<X>(CoreId, const _ActorInit&)`
takes its init by const reference (`engine.h:647`).

**Do not spend a week on perfect forwarding.** You will never write it here.

**(c) The framework is a museum of pre-move-semantics C++, and that is useful.**
`EngineCustomEventLoopFactory::EventLoopAutoPointer`'s *copy constructor* nulls out the
source (`engine.h:~185`, `other.eventLoop = 0` on a `const&` via a `mutable` member) —
the exact `std::auto_ptr` idiom that move semantics was invented to replace. Read it once
after watching the move-semantics talks; it is the best possible "before" picture.

**(d) `TimerProxy` is a determinism hazard.** `timer::TimerProxy::onTimeout(const DateTime&)`
(`include/trz/pattern/timer/timerproxy.h`, `tutorial/10_timer`) is driven by wall-clock
real time. `Time` is a plain `int64_t` nanosecond count
(`include/trz/engine/internal/time.h:39–48`), with `Time::Second/Millisecond/Microsecond/
Nanosecond` helper subclasses. The subject requires *"aucun comportement ne doit dépendre
de l'heure système en mode replay"* (subject, §3 *Déterminisme*).

**Design consequence:** funding ticks, mark-price refreshes and liquidation sweeps must be
driven by **scenario events on the simulated clock**, not by `TimerProxy`. Use `TimerProxy`
only for live mode, behind your abstract-clock interface (M0 requires exactly such a clock).

**(e) There is no supervision tree.** Simplx has `requestDestroy()` / `onDestroyRequest()` /
`acceptDestroy()` for cooperative shutdown (`actor.h:1543`, `:1708`; `tutorial/09_sync_exit`)
and an `AsyncExceptionHandler` for escaped exceptions — but **no Erlang/Akka-style
supervisor restart strategies**. Read the Erlang supervision material for the *reasoning*
(isolation makes restart possible), not for anything you can copy.

**(f) Undelivered events are a first-class mechanism, and M2 requires them.** M2 asks for
*"Gestion des événements non livrés"*. Simplx: `registerUndeliveredEventHandler<E>(*this)` +
`void onUndeliveredEvent(const E&)`; delivery fails on an invalid `ActorId`, on a receiver
that never called `registerEventHandler<E>`, or when the receiver throws
`ReturnToSenderException()` from its handler (`tutorial/06_undelivered_event_management`).
That last one is a clean way to implement M2's "transitions invalides" rejection path.

**(g) The escape hatch for disk and network.** `include/trz/pattern/bus/` +
`tutorial/13_cross_thread_bus` provide an SPSC lock-free ring buffer with explicit
cache-line padding between the read and write indices
(`include/trz/pattern/bus/ringbuffer.hpp:26–29`, `padding1[64 - sizeof(size_t)]`
*"force read_index and write_index to different cache lines"*). **This is how you honour
the "Chemin critique" box**: the journal writer, the Binance oracle feed and metrics live
on non-actor threads behind this bus, and the matching handlers only ever touch memory.
Read `ringbuffer.hpp` — it is 100 lines and it teaches false sharing better than any talk.

### 1.4 Documentation reality

There is **no prose manual**. The documentation is (i) 13 tutorial READMEs
(`tutorial/README.md`), and (ii) Doxygen comments in the headers, generated via
`doxygen doc/Doxyfile`. `include/trz/engine/actor.h` is 3471 lines, most of it comment.
**Budget 3 hours to read `actor.h` and `engine.h` as documents.** That is the real manual.

### 1.5 The C++ standard question (flagged for ticket 01)

`common_simplx.cmake`'s `trz_set_cxx_flags()` appends `--std=c++11` **unconditionally on
its first line**, then tests whether `CMAKE_CXX_FLAGS` contains `--std=c++` — a test that
its own first line has just guaranteed will succeed. Net effect: exactly one
`--std=c++11` is appended, and it is appended *after* any user-supplied flags. GCC honours
the last `-std` on the command line.

Two relevant local facts I did verify: **GCC 13.3.0's default is already C++17**
(`__cplusplus == 201703L` with no flags), and **CMake here is 3.28.3** (Simplx requires
≥ 3.7.2, fine). So the simplest route to C++17 is probably to not call
`trz_set_cxx_flags()` at all. `-Wall -Wextra -Wpedantic -Werror` on 2019 code under GCC 13
is a second, separate risk.

**I am not asserting what the effective standard ends up being** — the interaction between
`CMAKE_CXX_FLAGS` and `CMAKE_CXX_STANDARD` ordering is something ticket 01 must confirm
empirically. I am asserting only what the file says.

One thing that is *not* a problem: the codebase uses `throw()` (13 occurrences), which is
deprecated but still legal in C++17 (removed only in C++20). Non-empty dynamic exception
specifications — the ones actually removed in C++17 — appear **only in comments** (grepped;
`timerproxy.h:36`, `actor.h:669`, etc. are all `/* … */`).

---

## 2. BEFORE starting Exchange A (~20 hours)

Ordered. Do them in this order; each one makes the next cheaper.

### 2.1 The ergonomic delta — 2 h — **free**

**Bjarne Stroustrup, "C++11 FAQ"** — https://www.stroustrup.com/C++11FAQ.html
Written and maintained by Stroustrup himself; his stated design goal is *"max one page per
feature"*. This is the single best-targeted document in existence for a C++98 programmer,
because it is explicitly a *delta* document rather than a tutorial.

Read only these entries: `auto`, range-for, uniform/list initialisation, `nullptr`,
`constexpr`, `enum class`, `override`/`final`, `= default`/`= delete`, `using` type
aliases, `std::unique_ptr`/`std::shared_ptr`, lambdas, variadic templates.
Skim rvalue references here — §2.2 does it properly.

Caveat, stated on the page itself: maintenance has become sporadic and moved toward the
isocpp.org FAQ. It covers C++11 only; the C++17 additions are §2.6 and §3.

### 2.2 Move semantics and rvalue references — 4 h — **free**

This is the big one. Two talks, watched in order, then one hour at a compiler.

1. **Klaus Iglberger, "Back to Basics: Move Semantics (part 1 of 2)", CppCon 2019** —
   https://www.youtube.com/watch?v=St0MNEU5b0o (~60 min)
2. **Klaus Iglberger, "Back to Basics: Move Semantics (part 2 of 2)", CppCon 2019** —
   https://www.youtube.com/watch?v=pIzaZbKUw2s (~60 min)

   Session abstract: *"the motivation behind move semantics, the need for rvalue references
   and `std::move`, the reason for forwarding references and `std::forward`, and how to
   properly apply move semantics."* Part 1 covers the new special member functions, move
   constructor, move assignment and parameter conventions.
   Slides: https://github.com/CppCon/CppCon2019

   **Take:** why moving exists at all (the copy your C++98 code has been paying for),
   what `std::move` actually is (a cast, not a move), the moved-from state, and the rule of
   five as it now stands. **You may stop paying attention at forwarding references /
   `std::forward`** — see §5.

3. Optional 1 h if the value-category vocabulary is the sticking point:
   **Ben Saks, "Back to Basics: Understanding Value Categories", CppCon 2019** (Back to
   Basics track, Thursday 2019-09-19). Verified as a track entry; I did not verify a direct
   video URL — search CppCon's channel by title.

**Then spend one hour writing code**: a small `OrderBookLevel`-ish class with a `std::vector`
member; instrument copy ctor / move ctor / dtor with prints; put it in a `std::vector`,
force a reallocation, and watch. Then mark the move constructor `noexcept` and watch the
behaviour change. That last step is the one people skip and it is the one that matters —
see Core Guideline **C.66: Make move operations `noexcept`**.

### 2.3 Ownership, RAII, smart pointers — 2 h — **free**

Both from the CppCon 2019 "Back to Basics" track (track listing verified via Arthur
O'Dwyer's own write-up: https://quuxplusone.github.io/blog/2019/09/12/cppcon-2019-b2b-track/):

- **Arthur O'Dwyer, "Back to Basics: RAII and the Rule of Zero", CppCon 2019** —
  https://www.youtube.com/watch?v=7Qgd9B1KuMQ (~60 min).
  Abstract: small resource-managing classes follow the Rule of Three/Five; larger
  business-logic classes follow the Rule of Zero; plus copy-and-swap.
  **Take:** the Rule of Zero. For a C++98 programmer this is the single biggest change in
  daily habit — most of your classes should now declare *none* of the five.

- **Arthur O'Dwyer, "Back to Basics: Smart Pointers", CppCon 2019** —
  https://www.youtube.com/watch?v=xGDLkt-jBJ4 (~60 min).
  Covers unique ownership vs reference counting, `shared_ptr`'s control block, `weak_ptr`,
  `make_shared`/`make_unique`, `enable_shared_from_this`.
  **Take:** `unique_ptr` is free and is your default; `shared_ptr` is not free and you
  almost certainly do not need it in an actor system where lifetimes are owned by the
  engine. Slides mirror: https://nbviewer.org/github/mebusy/cppcontalk/blob/main/pdfs/back_to_basics_smart_pointers__arthur_odwyer__cppcon_2019.pdf

### 2.4 Pin it down with the Core Guidelines — 1.5 h — **free**

**C++ Core Guidelines** (Stroustrup & Sutter, eds.) —
https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines
Read *only* these rules. I verified every ID and title against the source Markdown:

| Rule | Title |
|---|---|
| R.1 | Manage resources automatically using resource handles and RAII |
| R.3 | A raw pointer (a `T*`) is non-owning |
| R.20 | Use `unique_ptr` or `shared_ptr` to represent ownership |
| R.21 | Prefer `unique_ptr` over `shared_ptr` unless you need to share ownership |
| R.22 / R.23 | Use `make_shared()` / `make_unique()` |
| R.30 | Take smart pointers as parameters only to explicitly express lifetime semantics |
| C.20 | If you can avoid defining default operations, do *(rule of zero)* |
| C.21 | If you define or `=delete` any copy, move, or destructor function, define or `=delete` them all *(rule of five)* |
| C.66 | Make move operations `noexcept` |
| F.15–F.21 | Parameter passing: in / in-out / will-move-from / forward, and returning multiple values |
| ES.11 | Use `auto` to avoid redundant repetition of type names |
| ES.20 | Always initialize an object |
| ES.23 | Prefer the `{}`-initializer syntax |
| ES.47 | Use `nullptr` rather than `0` or `NULL` |
| ES.71 | Prefer a range-`for`-statement to a `for`-statement when there is a choice |
| Enum.3 | Prefer class enums over "plain" enums |
| Con.5 | Use `constexpr` for values that can be computed at compile time |
| SL.str.2 | Use `std::string_view` or `gsl::span<char>` to refer to character sequences |

**F.15–F.21 is the highest-value block.** It is the modern answer to "how do I pass this
thing", which is the question a C++98 programmer asks a hundred times a day and now has a
different answer to.

### 2.5 The actor model as a concept — 3 h — **free**

Do this **before** touching Simplx's expression of it. The ticket's instinct is right: the
Erlang literature teaches it better than any C++ source.

**Joe Armstrong, "Making reliable distributed systems in the presence of software errors",
PhD thesis, Royal Institute of Technology, Stockholm, December 2003** —
https://erlang.org/download/armstrong_thesis_2003.pdf (free PDF, ~295 pp).
This is the primary text on the model. I extracted the table of contents to give exact
page numbers. Read **~25 pages, not 295**:

- **§2.4 "Concurrency oriented programming", pp. 19–27.** Sub-sections: 2.4.1 Programming
  by observing the real world (p. 21), 2.4.2 Characteristics of a COPL (p. 22),
  **2.4.3 Process isolation (p. 22)**, 2.4.4 Names of processes (p. 24),
  **2.4.5 Message passing (p. 25)**, 2.4.6 Protocols (p. 26).
  *This is the core.* Isolation is the load-bearing idea: because no process can corrupt
  another's memory, a failure is contained, and because nothing is shared, no locks exist
  to be contended.
- **§4.3 "Error handling philosophy" (p. 104)**, incl. 4.3.1 "Let some other process fix
  the error" (p. 104) and 4.3.2 "Workers and supervisors" (p. 106); **§4.4 "Let it crash"
  (p. 107)**.
- **§5.2 "Supervision hierarchies" (p. 118)** — 3 pages, read for the concept only.
  Simplx has no equivalent (§1.3(e)).

Then, 45 minutes, the modern restatement — **Akka official documentation** (Lightbend):

- *"Why modern systems need a new programming model"* —
  https://doc.akka.io/libraries/akka-core/current/typed/guide/actors-motivation.html
- *"How the Actor Model Meets the Needs of Modern, Distributed Systems"* —
  https://doc.akka.io/libraries/akka-core/current/typed/guide/actors-intro.html
  Sections: "Usage of message passing avoids locking and blocking", "Actors handle error
  situations gracefully". Explicitly covers mailboxes, local-not-shared state, and
  supervision.

**Take from the pair:** an actor = state + a mailbox + a behaviour that processes one
message at a time to completion. No shared mutable state ⇒ no locks ⇒ no data races
⇒ the "no global mutex in matching handlers" rule is a *consequence of the architecture*,
not a discipline you have to enforce.

### 2.6 Determinism under concurrency — 2.5 h — **free**

Why the subject can demand that the same seed yields the same functional hash, and what it
forbids.

1. **Thompson, Farley, Barker, Gee & Stewart, "Disruptor: High performance alternative to
   bounded queues for exchanging data between concurrent threads", LMAX, May 2011** —
   https://lmax-exchange.github.io/disruptor/disruptor.html
   (PDF: https://lmax-exchange.github.io/disruptor/files/Disruptor-1.0.pdf)
   Read **§2 "The Complexities of Concurrency"** and **§3 "Design of the LMAX Disruptor"**
   (~1 h). Verified content: locks require a kernel context switch and are catastrophic on
   a hot path; the ring buffer is **pre-allocated at startup** to eliminate allocation and
   GC; **false sharing** — two variables in the same cache line written by different
   threads contend exactly as if they were one variable.
   This is written *by an exchange, about an exchange*. It is the most on-point primary
   source in this whole document.

2. **Will Wilson (FoundationDB), "Testing Distributed Systems w/ Deterministic Simulation",
   Strange Loop 2014** — https://www.youtube.com/watch?v=4fFDFbi3toc (~45 min).
   Conference page: https://www.thestrangeloop.com/2014/testing-distributed-systems-w-slash-deterministic-simulation.html
   **Take:** the simulator intercepts *every* source of non-determinism — network, disk,
   **system time** — so that a failing schedule can be replayed identically. This is
   precisely M0's "clock abstrait : temps réel en live, temps simulé en replay" and
   `make replay SEED=42`. Watch it to understand *why* the abstraction has to be total: one
   un-abstracted `now()` and the property is gone.

3. **The C++ standard, [time.clock.steady]** — https://eel.is/c++draft/time.clock.steady
   Three minutes. `steady_clock` values *"never decrease as physical time advances"* and
   *"the clock may not be adjusted"*; `system_clock` explicitly **may** be adjusted at any
   moment. Rule for CrashLab: **`system_clock` never appears in engine code**; live mode
   uses `steady_clock` behind your clock interface, replay mode uses a counter.

**The checklist this produces** (derive it yourself while reading; it is the deliverable of
this half-day):

- No wall-clock reads in decision logic — only through the abstract clock.
- **No iteration over `std::unordered_map`/`unordered_set` where order affects output.**
  Iteration order is unspecified and varies with insertion history, bucket count and
  implementation. Use `std::map`, or sort explicitly, or iterate an ordered index.
  (Note Simplx's own `xthreadbus.hpp` uses `unordered_map`/`unordered_set` — that is setup
  bookkeeping, not decision logic, so it is fine; but it shows the trap is everywhere.)
- **No address-dependent behaviour** — never sort or key on a pointer value, never hash a
  pointer. ASLR makes it different every run.
- **No dependence on cross-core arrival order.** See §4.
- Every random draw from one seeded, explicitly-versioned PRNG whose call sequence is
  itself deterministic. The subject already demands this
  (*"le tirage doit être logarithmique, borné et déterministe à partir du seed"*).
- Iterate containers, never hash sets; fix the order in which the nine actors are polled.

### 2.7 The critical path: allocation and cache — 1.5 h — **free**

**Carl Cook (Optiver), "When a Microsecond Is an Eternity: High Performance Trading Systems
in C++", CppCon 2017** — https://www.youtube.com/watch?v=NH1Tta7purM (~60 min).
Session page: https://cppcon2017.sched.com/event/BgsH/when-a-microsecond-is-an-eternity-high-performance-trading-systems-in-c
Slides mirror: https://smallake.kr/wp-content/uploads/2023/04/When-a-Microsecond-Is-an-Eternity-Carl-Cook-CppCon-2017.pdf

**Take, at the "why this rule exists" level the ticket asks for:** the critical path is a
tiny fraction of the codebase, invoked rarely and unpredictably, and must run *without
delay*. Therefore: nothing on it may block, allocate, syscall, or touch cold memory.
Allocation is not slow because `malloc` is slow — it is slow because it may take a lock,
may fault in a page, and always pollutes cache. That is the entire justification for the
subject's *"Les allocations après warm-up doivent être mesurées et justifiées"*.

Then read Core Guidelines **Per.6 ("Don't make claims about performance without
measurements")** and **Per.19 ("Access memory predictably")** — 10 minutes, and Per.6 is
the one the soutenance will test you on.

Optional, if you want the mechanism rather than the rule:
**Ulrich Drepper, "What Every Programmer Should Know About Memory", Red Hat / LWN, 2007** —
https://people.freebsd.org/~lstewart/articles/cpumemory.pdf (114 pp, free).
**Read §3.3 only** (CPU cache operation, ~10 pp). Do not read the rest — see §5.

### 2.8 Make → CMake bridge — 2 h — **free**

You know Make. You need roughly 80 lines of CMake and a mental model, not a build-systems
course.

**The mental model, in one paragraph:** Make describes *how to produce files*. CMake
describes *targets and the properties that propagate between them*. `target_link_libraries(a
PUBLIC b)` does not merely link — it says "anything that uses `a` also inherits `b`'s
include directories, compile definitions and flags". `PRIVATE` = I need it, my users don't.
`INTERFACE` = my users need it, I don't. `PUBLIC` = both. Get that and you have 90% of it.

1. **CMake official tutorial** — https://cmake.org/cmake/help/latest/guide/tutorial/index.html
   (free, first-party). Verified step list: Step 0 *Before You Begin*, Step 1 *Getting
   Started with CMake*, Step 2 *CMake Language Fundamentals*, Step 3 *Configuration and
   Cache Variables*, Step 4 *In-Depth CMake Target Commands*, Step 5 *In-Depth CMake Library
   Concepts*, Step 6 *System Introspection*, Step 7 *Custom Commands and Generated Files*,
   Step 8 *Testing and CTest*, Step 9 *Installation*, Step 10 *Finding Dependencies*,
   Step 11 *Miscellaneous*.
   **Do Steps 1, 2, 4 and 8. Skip 0, 3, 5, 6, 7, 9, 10, 11.** (~90 min.)
   Step 1's four exercises — building an executable, building a library, linking them,
   subdirectories — plus Step 4's target commands are literally the whole of what CrashLab
   needs. Step 8 gives you `make test`, which the subject requires.

2. **Daniel Pfeifer, "Effective CMake", C++Now 2017** —
   video https://www.youtube.com/watch?v=bsXLMQ6WgIk,
   slides https://github.com/boostcon/cppnow_presentations_2017/blob/master/05-19-2017_friday/effective_cmake__daniel_pfeifer__cppnow_05-19-2017.pdf
   Pfeifer is a CMake contributor; this is the canonical "how to not write bad CMake" talk.
   **Skim the slides (20 min); watch only if the target/property model has not clicked.**
   Ignore everything about packaging, `install`/`export` and cross-compiling.

**Keep your Makefile.** The subject demands `make setup / build / test / coverage / run /
record-oracle / replay SEED=42 / scenario-crash SEED=42 / benchmark`. The clean shape is a
thin top-level `Makefile` whose targets invoke `cmake --build` and the produced binaries.
You already know how to write that half.

### 2.9 Read the framework — 3 h — **free**

Last, because now it will be legible. In this order:

1. `tutorial/README.md`, then tutorials **01, 03, 04, 06, 08, 09, 10** (READMEs + `.cpp`).
   Skip 02, 05, 07, 11, 12 for now; 13 when you wire the journal/oracle (§3).
2. `include/trz/engine/actor.h` — read as a document. `Actor`, `Actor::Event`,
   `Event::Pipe`, `ActorId`, `Callback`, `registerCallback`, `requestDestroy`/
   `onDestroyRequest`.
3. `include/trz/engine/engine.h` — `StartSequence`, `CoreSet`, `ServiceIndex`,
   `setEventAllocatorPageSizeByte`, red-zone/blue-zone cores.
4. `include/trz/pattern/bus/ringbuffer.hpp` — 100 lines, and the best false-sharing lesson
   you will get.

**Do not read** `include/trz/engine/internal/**` — Simplx's own docs say so:
*"used internally by the Simplx runtime; they're not documented and subject to change.
You shouldn't need those directly in order to write client applications anyway."*
(`doc/index.dox`). The two exceptions worth 10 minutes each: `internal/time.h` (because
`Time` is your nanosecond type) and `internal/cacheline.h` (because it explains the
alignment discipline).

---

## 3. LEARN IN PLACE while building

Do **not** front-load any of this.

### 3.1 C++17 features, on demand — 30–60 min each

Which of them will actually be used in CrashLab, and where:

| Feature | Verdict | Where in CrashLab |
|---|---|---|
| **Structured bindings** | **Yes, constantly** | iterating price levels, `auto [px, level] : book`, multi-return from matching |
| **`if`/`switch` with initialiser** | **Yes** | `if (auto it = orders.find(id); it != orders.end())` — the order-lookup you write 50 times |
| **`std::optional`** | **Yes** | "best bid may not exist", "order may not be found", parse results |
| **`std::string_view`** | Yes, at the edges | JSON/protocol parsing, symbol handling — **never stored in an event** (it is a non-owning view; storing one in a POD event that outlives the buffer is a dangling read) |
| **`std::variant`** | **Probably not** — see §5 | you have `Actor::Event` subclasses and `registerEventHandler`; a second dispatch mechanism is redundant |
| **`if constexpr`** | Only if you template your engine over live/replay clock | otherwise skip |
| **`std::from_chars`** | Maybe | allocation-free integer parsing on the oracle feed, if parsing shows up in profiles |

Reference options:

- **Free:** cppreference.com (`en.cppreference.com`) for each feature; and the free final
  C++17 working draft **N4659** —
  https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/n4659.pdf — when you need the
  actual wording. (N4659 is the last freely-available pre-publication C++17 draft.)
- **Paid, and worth it if you like books:** **Nicolai M. Josuttis, "C++17 — The Complete
  Guide", 1st ed.** — https://leanpub.com/cpp17 (~$19.90 min / $39.90 suggested; ~91,000
  words). TOC verified. Read only: **Ch. 1 Structured Bindings**, **Ch. 2 `if` and `switch`
  with Initialization**, **Ch. 15 `std::optional<>`**, **Ch. 19 String Views**, and
  **Ch. 10 Compile-Time `if`** if you end up needing it. Ch. 16 is `std::variant` — see §5.
  Skip Parts IV, V, VI entirely.

### 3.2 `std::chrono` — 1.5 h, when you build the abstract clock (M0)

**Howard Hinnant, "A `<chrono>` Tutorial", CppCon 2016** —
https://www.youtube.com/watch?v=P32hvk8b13M
Slides: https://github.com/CppCon/CppCon2016/blob/master/Tutorials/A%20chrono%20Tutorial/A%20chrono%20Tutorial%20-%20Howard%20Hinnant%20-%20CppCon%202016.pdf
Hinnant is the author of `<chrono>`; this is as primary as a talk gets.

**Take:** `duration` as a compile-time-checked ratio, `time_point` as duration-since-epoch
on a specific clock, why mixing clocks is a type error, and how the conversions work.
You need this to build M0's abstract clock cleanly — a `Clock` concept with `now()`
returning `std::chrono::nanoseconds`, implemented once over `steady_clock` and once over a
replay counter.

Interop note: Simplx's own `Time` is a raw `int64_t` nanosecond count
(`internal/time.h`), so you will write a one-line adaptor in both directions.
Do **not** try to replace Simplx's `Time` with `chrono`.

### 3.3 Templates as written today — 1 h, when `actor.h` stops making sense

**Dan Saks, "Back to Basics: Function and Class Templates", CppCon 2019** (Back to Basics
track, Thursday 2019-09-19; verified as a track entry, direct video URL not verified —
search CppCon's channel by title).

You need exactly enough to *read* Simplx: template parameters, class templates, member
function templates, variadic parameter packs (`template<class... _Args>`), and the CRTP
pattern that Simplx uses heavily (`MultiDoubleChainLink<Actor,2u>`,
`DoubleChain<0u, Chain>`). You do **not** need to write any of it.

Do not buy a templates book — see §5.

### 3.4 Measuring allocations after warm-up

The subject requires them "mesurées et justifiées". The technique is a global
`operator new` / `operator delete` counting shim toggled after warm-up, plus a heap
profiler (`valgrind --tool=massif`, `heaptrack`) for the offline picture. This is a
half-hour of work, not a reading item — but Carl Cook's talk (§2.7) is where the
justification narrative for the report comes from.

### 3.5 Optional, if the low-latency angle interests you for the soutenance

**David Gross (Optiver), "Trading at light speed: designing low latency systems in C++",
Meeting C++ 2022** — https://www.youtube.com/watch?v=8uAW5FQtcvE
Talk page: https://meetingcpp.com/2022/Talks/items/Trading_at_light_speed__designing_low_latency_systems_in_Cpp.html
Covers data modelling for performance, using multiple cores, concurrency in trading
systems, system tuning. Overlaps heavily with Carl Cook; watch only if you want a second
pass. **Note:** it is a Meeting C++ 2022 talk, not CppCon, despite how it is often
mislabelled online.

---

## 4. Determinism in Simplx specifically — the thing no source will tell you

Because I could not find this documented anywhere, here is what the source implies, clearly
marked as inference.

`Pipe::push` chains events into the destination's event chain in push order
(`actor.h:2713–2716`, `destinationEventChain->push_back(ret)`), so **per-pipe FIFO looks
like it holds**. But cross-core delivery goes through a shared write cache that each reader
node drains on its own schedule (`src/engine/node.cpp`, `WriterSharedHandle` /
`ReaderSharedHandle`, `usedEventAllocatorPageChain` swap at `node.cpp:1201`). **The
interleaving of events arriving at one actor from two different cores is therefore a
function of thread timing, and I would not bet a functional hash on it.**

**Design consequence for M2 — this is the single most important architectural decision in
this ticket:**

- Put `MatchingEngineActor` on **one core**, and make it the only writer of book state.
  (This is exactly LMAX's "single thread owning all writes to a single resource", §2.6.)
- Give every inbound order a **sequence number assigned by one sequencer** (the
  `GatewayActor`, on one core), and have the matching engine process **in sequence-number
  order**, not arrival order — buffering out-of-order arrivals if they can occur.
- Do not let the functional hash depend on how many cores you use, beyond what the subject
  already fixes ("le même nombre de workers").

**This inference should be confirmed empirically** — a two-core ping-storm test that checks
whether interleaving is stable across runs — and that belongs to ticket 01 or 02, not here.

---

## 5. SKIP ENTIRELY

The most valuable section in this document. Every item below is something a reasonable
person would put on this list and should not.

### 5.1 Skip because you already know it

- **Every beginner C++ resource.** *C++ Primer*, *Accelerated C++*, learncpp.com, any
  "C++ for beginners" course. You have written a lot of C++98. Pointers, references,
  arrays, classes, inheritance, virtual dispatch, operator overloading, templates-as-
  containers, the preprocessor, UB — all already yours.
- **Scott Meyers, *Effective C++* (3rd ed.) and *More Effective C++*.** Excellent books,
  entirely about C++98. Zero delta.
- **Anything teaching RAII from scratch.** You already do this; you just call it something
  else.

### 5.2 Skip because this project will never use it

- **Perfect forwarding, forwarding/universal references, `std::forward`, reference
  collapsing.** Verified: Simplx's `Pipe::push` does not forward (§1.3(b)). You will not
  write a forwarding wrapper in CrashLab. In **Scott Meyers, *Effective Modern C++*
  (O'Reilly, 2014)** — https://www.oreilly.com/library/view/effective-modern-c/9781491908419/ch05.html
  — Chapter 5 is Items 23–30; **skip Items 24, 25, 26, 27, 28 and 30 entirely.**
  If you own the book, Item 23 (`std::move`/`std::forward`) and Item 29 ("Assume that move
  operations are not present, not cheap, and not used") are the only two worth 20 minutes,
  and Iglberger's talks already cover Item 23.
- **`std::thread`, `std::mutex`, `std::condition_variable`, `std::atomic`, and the C++
  memory model (`memory_order_*`).** The whole point of the actor model is that you do not
  write these. Simplx owns the threads; handlers run to completion on one thread per core.
  The subject *forbids* global mutexes on the matching path. **Rainer Grimm's "Back to
  Basics: Atomics, Locks, and Tasks" (CppCon 2019, parts 1–2) is a fine talk that you
  should not watch for this project.**
- **Writing lock-free data structures.** Michael–Scott queues, hazard pointers, ABA,
  Herlihy & Shavit's *The Art of Multiprocessor Programming*, Fedor Pikus's lock-free
  talks. You need to *understand why locks are bad on a hot path* (§2.7 covers it in an
  hour); you need to *use* one SPSC ring buffer, and Simplx already ships it
  (`include/trz/pattern/bus/ringbuffer.hpp`). Reading its 100 lines is the entire
  requirement.
- **`std::variant` and `std::visit`.** Tempting for order/event types. But Simplx already
  gives you typed dispatch via `Actor::Event` subclasses + `registerEventHandler<E>` +
  `onEvent(const E&)`, and events must be trivially destructible POD (§1.3(a)) — which
  `variant` complicates rather than helps. Josuttis Ch. 16 is skippable.
- **`std::any`, `std::filesystem`, polymorphic memory resources (PMR), parallel STL
  algorithms, `std::launder`, `std::byte`, over-aligned `new`/`delete`, class template
  argument deduction, fold expressions.** Josuttis C++17 Parts IV, V, VI and Chs. 9, 11–14,
  17, 18, 20. Not one of these earns its keep here.
- **Coroutines, concepts, ranges, modules, `std::format`, `std::span`, `std::jthread` —
  i.e. all of C++20/23.** Simplx is a C++11 codebase; the subject says C++17; the
  `throw()` usages in Simplx are legal in C++17 and **removed in C++20**. Going past C++17
  actively costs you.
- **Boost.** Not required by the subject, and every Boost dependency is a build-ticket
  problem you do not need.

### 5.3 Skip because it is the wrong depth

- **Vandevoorde, Josuttis & Gregor, *C++ Templates: The Complete Guide*, 2nd ed.
  (Addison-Wesley, 2017, 822 pp).** A superb reference. **Do not read it.** If you ever
  need a specific answer, look up that one thing. The ticket's own criterion — "enough to
  read library code, not enough to write a metaprogramming library" — is satisfied by one
  hour (§3.3).
- **Drepper's *What Every Programmer Should Know About Memory* beyond §3.3.** 114 pages,
  from 2007, much of it about NUMA topologies and prefetch instruction scheduling you will
  never touch. §3.3 alone gives you the cache mental model.
- **Josuttis, *C++ Move Semantics — The Complete Guide*** (https://leanpub.com/cppmove,
  ~$9.90 min / $19.90 suggested; TOC verified: Part I Chs. 1–8, Part II Chs. 9–12,
  Part III Chs. 13–15). The two Iglberger talks cover Part I's substance in two hours for
  free. **Buy this only if you finish §2.2 and still feel shaky** — and then read only
  Ch. 1 *The Power of Move Semantics*, Ch. 2 *Core Features of Move Semantics*, Ch. 3
  *Move Semantics in Classes*, Ch. 6 *Moved-From States* and Ch. 7 *Move Semantics and
  `noexcept`*. **Part II (Chs. 9–12) is entirely perfect forwarding — skip it**, per §5.2.
- **Stroustrup, *A Tour of C++*, 2nd ed. (Addison-Wesley, July 2018, ISBN
  978-0-13-499783-4, ~240 pp)** — https://www.stroustrup.com/tour2.html. Covers C++17 and
  is explicitly aimed at *"people who already know C++ or at least are experienced
  programmers"*, which makes it the single best *paid* option if you would rather read one
  short book than watch talks. It is on this list only because **it overlaps ~90% with the
  free C++11 FAQ + §2.2–2.4 path and costs money.** Legitimate substitute; not an addition.

### 5.4 Skip because it is history, not engineering

- **Hewitt, Bishop & Steiger, "A Universal Modular ACTOR Formalism for Artificial
  Intelligence", IJCAI 1973, pp. 235–245.** The origin of the actor model. Dense, of its
  era, and Armstrong §2.4 plus the Akka guide teach you more in less time. Cite it in the
  report; do not read it. (ACM: https://dl.acm.org/doi/10.5555/1624775.1624804)
- **Gul Agha, *ACTORS: A Model of Concurrent Computation in Distributed Systems*
  (MIT Press, 1986).** Same verdict. *I did not verify a free download location for this
  one — do not assume one exists.*
- **Learning Erlang or OTP.** Read Armstrong's *reasoning*; do not learn `gen_server`,
  `supervisor` behaviours, or Erlang syntax. Simplx has no supervision tree to map them
  onto (§1.3(e)).
- **The C++ Actor Framework (CAF)** — https://actor-framework.readthedocs.io/en/stable/.
  A real, maintained C++ actor library with a genuinely good "Concepts / Actor Model /
  Terminology" chapter. Worth **15 minutes** if you want the actor vocabulary restated in
  C++ terms. It is **not** what the subject specifies and reading its API will actively
  confuse you about Simplx's.
- **Martin Fowler, "The LMAX Architecture" (2011)** — https://martinfowler.com/articles/lmax.html.
  Well written and directly relevant to event-sourced deterministic replay, but it is a
  **secondary write-up**; the Disruptor technical paper (§2.6) is the primary source and
  you should read that instead. Listed here so you recognise it and skip it.

### 5.5 Skip because it is somebody else's ticket

- **Getting Simplx to build under GCC 13 / C++17.** Ticket 01. §1.5 records what I found;
  do not go down that hole from this ticket.
- **CMake beyond ~150 lines**: toolchain files, generator expressions past the basics,
  `install()`/`export()`, CPack, `FetchContent` for anything but googletest,
  cross-compilation.
- **Doxygen/Sphinx authoring.** You will *generate* Simplx's docs once (`doxygen doc/Doxyfile`)
  and never write any.

---

## 6. Budget summary

| # | Item | Cost | Free? |
|---|---|---|---|
| 2.1 | Stroustrup C++11 FAQ, selective | 2 h | free |
| 2.2 | Iglberger, Move Semantics 1 & 2 + 1 h at a compiler | 4 h | free |
| 2.3 | O'Dwyer, RAII/Rule of Zero + Smart Pointers | 2 h | free |
| 2.4 | Core Guidelines, ~20 named rules | 1.5 h | free |
| 2.5 | Armstrong thesis §2.4/§4.3–4.4/§5.2 + Akka guide | 3 h | free |
| 2.6 | LMAX Disruptor §2–3 + Wilson + [time.clock.steady] | 2.5 h | free |
| 2.7 | Carl Cook + Per.6/Per.19 (+ Drepper §3.3) | 1.5 h | free |
| 2.8 | CMake tutorial Steps 1/2/4/8 + Pfeifer slides | 2 h | free |
| 2.9 | Simplx tutorials + `actor.h` + `engine.h` + `ringbuffer.hpp` | 3 h | free |
| | **Pre-M2 total** | **~21.5 h** | **entirely free** |
| 3.1 | C++17 features on demand | ~3 h spread | free (or $20 book) |
| 3.2 | Hinnant `<chrono>` tutorial | 1.5 h | free |
| 3.3 | Dan Saks, templates | 1 h | free |
| 3.5 | David Gross (optional) | 1 h | free |
| | **In-place total** | **~6.5 h** | |

**Nothing on the critical path costs money.** The only paid items (Josuttis C++17,
Josuttis Move Semantics, Meyers, Stroustrup's *Tour*) are substitutes or optional depth,
never prerequisites.

---

## 7. Honest uncertainties

Flagged rather than guessed, per the ticket's instruction.

1. **Two CppCon 2019 talks I recommend by title/speaker but whose direct video URLs I did
   not verify:** Ben Saks, *"Back to Basics: Understanding Value Categories"* (§2.2) and
   Dan Saks, *"Back to Basics: Function and Class Templates"* (§3.3). Both appear in the
   verified Back-to-Basics track listing at
   https://quuxplusone.github.io/blog/2019/09/12/cppcon-2019-b2b-track/ (written by the
   track chair, Arthur O'Dwyer). Search the CppCon YouTube channel by exact title.
2. **`josuttis.com` and `cppmove.com` failed TLS verification** from this machine
   ("unable to verify the first certificate"). The Josuttis book TOCs in §3.1 and §5.3 come
   from the **Leanpub** listing pages instead, which I did fetch successfully.
   `stroustrup.com/Tour2_toc.pdf` returned 404, so the *Tour of C++* 2nd ed. chapter list
   is **not** verified — I quote only its publisher, date, ISBN, page count and stated
   audience, all from https://www.stroustrup.com/tour2.html.
3. **`en.cppreference.com` returned HTTP 403** to my fetcher. I therefore cite the ISO
   working draft (https://eel.is/c++draft/time.clock.steady, N4659) for the clock guarantees
   rather than paraphrasing cppreference. cppreference remains the right day-to-day
   reference; I just could not read it here.
4. **Gul Agha's *ACTORS* (1986)**: I did not verify any free download. Do not assume one.
5. **§4 (cross-core event ordering in Simplx) is inference from source, not documentation.**
   I found no statement anywhere in `doc/`, `README.md` or the tutorial READMEs about
   ordering guarantees between events from different cores. The architectural advice
   (single-core matching engine + explicit sequencer) is safe regardless, but the
   underlying claim needs an empirical check.
6. **§1.5 (the C++ standard flag)**: I verified what `common_simplx.cmake` contains and
   that GCC 13.3 here defaults to C++17. I did **not** verify what standard a Simplx build
   actually ends up compiled with, because the ticket forbids building. That is ticket 01's
   to establish.
7. **The Simplx "no event destructor" finding** rests on an exhaustive grep for explicit
   destructor calls (`->~Name`) across `include/` and `src/`, which found only
   `~EventTable`, `~Collection`, `~T` (in allocators) and `~value_type`. I consider it
   solid, but it is worth one five-minute empirical confirmation — an event with a
   destructor that prints — before you design the whole event schema around it.

---

## Appendix: every source cited, in one list

**Free**

- Bjarne Stroustrup, *C++11 FAQ* — https://www.stroustrup.com/C++11FAQ.html
- Klaus Iglberger, *Back to Basics: Move Semantics (part 1 of 2)*, CppCon 2019 — https://www.youtube.com/watch?v=St0MNEU5b0o
- Klaus Iglberger, *Back to Basics: Move Semantics (part 2 of 2)*, CppCon 2019 — https://www.youtube.com/watch?v=pIzaZbKUw2s
- CppCon 2019 slides repository — https://github.com/CppCon/CppCon2019
- Arthur O'Dwyer, *Back to Basics: RAII and the Rule of Zero*, CppCon 2019 — https://www.youtube.com/watch?v=7Qgd9B1KuMQ
- Arthur O'Dwyer, *Back to Basics: Smart Pointers*, CppCon 2019 — https://www.youtube.com/watch?v=xGDLkt-jBJ4
- Arthur O'Dwyer, *Back to Basics at CppCon 2019* (track listing) — https://quuxplusone.github.io/blog/2019/09/12/cppcon-2019-b2b-track/
- Stroustrup & Sutter (eds.), *C++ Core Guidelines* — https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines
- Joe Armstrong, *Making reliable distributed systems in the presence of software errors*, PhD thesis, KTH Stockholm, Dec 2003 — https://erlang.org/download/armstrong_thesis_2003.pdf
- Akka documentation, *Why modern systems need a new programming model* — https://doc.akka.io/libraries/akka-core/current/typed/guide/actors-motivation.html
- Akka documentation, *How the Actor Model Meets the Needs of Modern, Distributed Systems* — https://doc.akka.io/libraries/akka-core/current/typed/guide/actors-intro.html
- Thompson, Farley, Barker, Gee & Stewart, *Disruptor*, LMAX, May 2011 — https://lmax-exchange.github.io/disruptor/disruptor.html · PDF https://lmax-exchange.github.io/disruptor/files/Disruptor-1.0.pdf
- Will Wilson, *Testing Distributed Systems w/ Deterministic Simulation*, Strange Loop 2014 — https://www.youtube.com/watch?v=4fFDFbi3toc
- ISO C++ draft, *[time.clock.steady]* — https://eel.is/c++draft/time.clock.steady
- C++17 final working draft **N4659** — https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/n4659.pdf
- Carl Cook, *When a Microsecond Is an Eternity*, CppCon 2017 — https://www.youtube.com/watch?v=NH1Tta7purM · slides https://smallake.kr/wp-content/uploads/2023/04/When-a-Microsecond-Is-an-Eternity-Carl-Cook-CppCon-2017.pdf
- Ulrich Drepper, *What Every Programmer Should Know About Memory*, 2007 — https://people.freebsd.org/~lstewart/articles/cpumemory.pdf
- CMake official tutorial — https://cmake.org/cmake/help/latest/guide/tutorial/index.html
- Daniel Pfeifer, *Effective CMake*, C++Now 2017 — https://www.youtube.com/watch?v=bsXLMQ6WgIk · slides https://github.com/boostcon/cppnow_presentations_2017/blob/master/05-19-2017_friday/effective_cmake__daniel_pfeifer__cppnow_05-19-2017.pdf
- Howard Hinnant, *A `<chrono>` Tutorial*, CppCon 2016 — https://www.youtube.com/watch?v=P32hvk8b13M · slides https://github.com/CppCon/CppCon2016/blob/master/Tutorials/A%20chrono%20Tutorial/A%20chrono%20Tutorial%20-%20Howard%20Hinnant%20-%20CppCon%202016.pdf
- David Gross, *Trading at light speed*, Meeting C++ 2022 — https://www.youtube.com/watch?v=8uAW5FQtcvE
- Simplx source and tutorials — `/home/ak/CrashLab/vendor/simplx`
- C++ Actor Framework manual (skim only) — https://actor-framework.readthedocs.io/en/stable/

**Paid (all optional)**

- Nicolai M. Josuttis, *C++17 — The Complete Guide* — https://leanpub.com/cpp17 (~$19.90–39.90)
- Nicolai M. Josuttis, *C++ Move Semantics — The Complete Guide* — https://leanpub.com/cppmove (~$9.90–19.90)
- Bjarne Stroustrup, *A Tour of C++*, 2nd ed., Addison-Wesley 2018, ISBN 978-0-13-499783-4 — https://www.stroustrup.com/tour2.html
- Scott Meyers, *Effective Modern C++*, O'Reilly 2014 — https://www.oreilly.com/library/view/effective-modern-c/9781491908419/ (Items 23 and 29 only)
- Vandevoorde, Josuttis & Gregor, *C++ Templates: The Complete Guide*, 2nd ed., Addison-Wesley 2017 — reference only, do not read
