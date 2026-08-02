# Does Simplx build and run here?

Type: task
Status: open
Blocked by: —

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
