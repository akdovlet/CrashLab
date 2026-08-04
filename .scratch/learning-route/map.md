# Learning route through CrashLab

Label: `wayfinder:map`

## Destination

A sequenced learning + build route through CrashLab's eleven milestones, written for
one solo developer. Each step of the route pairs five things:

1. **build** — the code that step produces
2. **learn** — the finance / CS concepts that must be understood *before* writing it
3. **read** — named sources, not "go research margin"
4. **code gate** — the subject's own acceptance criteria for that milestone
5. **understanding gate** — the soutenance question(s) that step earns the right to answer

Optimised for depth of understanding, not delivery speed. The route is the
deliverable; building CrashLab is a separate effort that follows it.

## Notes

**Domain** — market microstructure and event-driven systems engineering.

**Who this is for** — a solo developer, fluent in C++98 and Make, comfortable
learning CMake. New to: modern C++ (move semantics, RAII-by-default, C++11/14/17
idioms), actor models, Python asyncio, event-driven/event-sourced design,
testing and benchmarking discipline, and all of finance. The stated goal is to
learn all of it — the route must carry three learning surfaces at once
(finance, modern C++/concurrency, engineering discipline) without drowning.

**No deadline.** The subject's grading caps (won't build = 0, one exchange = 55,
non-deterministic replay = 70, coverage < 50% = 75) are a checklist the route
satisfies on the way, not the thing it optimises for.

**Understanding gates** come from the ten soutenance questions in §7 of the
subject. They are the measure of "learned".

**Subject** — `crashlab_subject_fr.pdf` at the repo root; plain-text extract at
`.scratch/learning-route/subject.txt` for grepping and for research agents.

**Skills every session should consult** — `/grilling` and `/domain-modeling` for
the decision tickets, `/research` for the reading-list tickets, `/prototype` for
the route-format ticket.

**Language** — the subject is French; the route document should be written in
whichever language the reader prefers, but finance terminology should carry the
English term alongside, since virtually all the reading will be in English.

## Decisions so far

<!-- one line per closed ticket: gist + link -->

- [Does Simplx build and run here?](issues/01-does-simplx-build-and-run-here.md)
  — **usable with patches.** 5 files, +23/−7, and it works: 13/13 tutorials build
  and run at C++17, 14/14 unit tests pass, cross-core messaging and the timer both
  verified. **The Exchange A contingency does not fire.** One patch (a
  `decltype(&pclose)` template argument GCC 13 rejects) was blocking the C++11
  build too — that is why `vendor/simplx/build/` never existed. Three of ticket
  06's findings confirmed, one of them worse than described: **`-DCMAKE_CXX_FLAGS
  ="-std=c++17"` is silently ignored** (`--std=c++11` is appended after it), so
  always use `-DCMAKE_CXX_STANDARD=17`. The **event-POD leak hides below the SSO
  threshold** — tutorial 03 is Valgrind-clean until you lengthen the string past
  15 chars, then 172 bytes lost. `breakThrow`'s `throw()` was aborting the process
  on every event-allocator `bad_alloc`, in C++11 too. Ticket 14 gets a seam:
  `TimerActor::onCallback()` is `virtual`. New: **the engine busy-spins a core at
  100%**, so wall-clock benchmarking is meaningless and `benches/` needs to
  measure bounded event batches.
  Deliverable: [`research/01-simplx-build-and-run.md`](research/01-simplx-build-and-run.md),
  patch: [`research/01-simplx-cpp17.patch`](research/01-simplx-cpp17.patch).

- [What one route step looks like on the page](issues/02-what-one-route-step-looks-like.md)
  — **a step is capped, and the cap does the milestone-splitting.** Spine ≤ 65 lines,
  whole step ≤ 150 lines / ~1,500 words, measured on the M1 write-up rather than
  guessed. Steps are numbered independently and milestone-tagged; **M1 is two steps**.
  The check that keeps splitting honest: every milestone acceptance criterion appears
  in exactly one step's `gate — subject`. `read:` carries a one-line extract plus a
  citation, never a summary — so **the research docs' section numbers are now an
  interface** and must stay stable. Reading is costed in hours, building in multiples
  of the M1 step. Three fields added: `after:`, `demo:`, and **`forces:` — decisions a
  step makes irreversible**, which surfaced that **the subject never assigns the
  oracle a language** (C++17 to A, Python to B, nothing to the oracle).
  Deliverable: [`research/02-route-step-prototype.md`](research/02-route-step-prototype.md).

- [Reading list: order books and market microstructure](issues/03-reading-order-books-microstructure.md)
  — ~20 sources, six stages; **~28–32 h and one book to buy** (Harris ch. 2/3/4/6)
  before M2, everything else free. The subject's order state machine **is FIX 4.4**
  and should be taught as such; soutenance Q3 has a verbatim answer in Nasdaq
  OUCH 5.0 §1.2; soutenance Q2 is documented by BitMEX's "Fair Price Marking",
  which describes exactly the A-vs-B experiment. Price-time priority is a
  *choice* — four venues use four different same-price allocation rules.
  Deliverable: [`research/03-order-books-microstructure.md`](research/03-order-books-microstructure.md).

- [C++98 to C++17 and the actor model: the minimum on-ramp](issues/06-cpp98-to-cpp17-and-actors.md)
  — **~21.5 h before Exchange A, ~6.5 h in place, every pre-M2 source free.**
  The agent read the vendored Simplx source first, which cut the syllabus: no
  perfect forwarding (`Pipe::push` doesn't forward), no threading primitives or
  lock-free work (one pinned thread per core, no shared state). Found that
  **event payloads must be trivially destructible POD** — destructors are never
  run, and tutorials 03/04/08 leak — which happens to align with the subject's
  scaled-integer requirement. `TimerProxy` is wall-clock driven and is a
  determinism hazard.
  Deliverable: [`research/06-cpp17-and-actors.md`](research/06-cpp17-and-actors.md).

- [Reading list: risk measurement](issues/05-reading-risk-measurement.md)
  — ~40 sources in six tracks (execution cost, VaR/ES, aggregation, drawdown/
  delta, latency, pre-trade controls). Soutenance Q8 is answered from a primary
  regulatory source: **BCBS Working Paper 19** states that summing
  compartmentalised VaR "may understate the risk" where the separation exists
  "due only to accounting rules" — exactly the A/B split. The **SEC's Knight
  Capital order ¶20–27** explains why the subject's ten pre-trade controls are
  those ten. **Basel's 1996 backtesting framework** (green 0–4 / yellow 5–9 /
  red 10+ over 250 days) should be promoted into the route: it turns M8 from
  "computed a number" into "validated a model". Latency track entirely free.
  Deliverable: [`research/05-risk-measurement.md`](research/05-risk-measurement.md).

- [Reading list: perpetuals, margin, funding and liquidation](issues/04-reading-perpetuals-margin-liquidation.md)
  — ~30 sources, **~32 h, one paid item in the whole list** (Hull, 2 chapters).
  **Exchange B's formula already runs in production twice** (OKX: `index +
  MA(mid − index)`; Hyperliquid: `oracle + EMA₁₅₀ₛ(mid − oracle)`, with an EMA
  rule correct for irregular intervals — copy it). BitMEX supplies a defensible
  `max_basis`: **one maintenance margin**. The **mark-price spectrum** from dYdX
  (pure oracle) to Exchange A (last price alone) is the M7 report's thesis in
  one line, and names three robustness techniques — exclusion, bounding,
  out-voting — plus BitMEX's orthogonal **quality gate**. The **10–11 Oct 2025
  Binance USDe/BNSOL/WBETH event (~$283M)** is the Exchange A loop run for real.
  **Liquidation rate limiting** is the standout implementable idea and a real
  M7 experiment.
  Deliverable: [`research/04-perpetuals-margin-liquidation.md`](research/04-perpetuals-margin-liquidation.md).

## Not yet specified

- **Which side of the house the oracle lives on.** Surfaced by ticket 02: the subject
  assigns C++17 to Exchange A and Python 3.12 to Exchange B, gives the oracle its own
  top-level directory, and never says what it is written in. This is a design decision
  and stays out of scope as one — but it has a *sequencing* consequence the route
  cannot dodge: if the oracle is Python, then M1 is the first asyncio code and pulls
  that reading forward ahead of M2; if it is C++, M1 pulls the modern-C++ on-ramp
  forward instead. The route has to place the reading either way.
- **How deep to go on options and Black-Scholes.** M9 is only 4 points but
  Black-Scholes, implied vol by bisection, and delta-hedging are a large theory
  detour. Downstream of the depth decision.
- **Whether a warm-up project belongs before M0.** A throwaway toy matching
  engine — 200 lines, no actors, no margin — might be the cheapest way to make
  price-time priority concrete before the real architecture lands on top of it.
  Depends on the build-order and cadence decisions.
- **How to prove the M7 cascade is caused by mark-price design and not a
  matching bug.** This is the crux of the whole subject and the hardest thing to
  verify. Can't be specified until margin and liquidation mechanics are
  understood.
- **Which of the twelve deliverables double as learning artefacts.** The subject
  already demands a crash report, a VaR report, a market-maker analysis, a
  benchmark report. Some of these may serve as the "explain it in your own
  words" checkpoint; others are pure paperwork.
- **Whether Postgres, Docker and persistence deserve route time** or are
  incidental infrastructure to be handled as they arise.
- **What is genuinely learnable in M10 (KYC/AML)** versus what is CRUD, RBAC and
  field encryption that teaches nothing about markets.
- ~~**How the route handles a Simplx failure.**~~ **Resolved by ticket 01** —
  Simplx builds, runs and passes its tests at C++17 with a 30-line patch set.
  Exchange A keeps its planned shape. The determinism half remains open as
  ticket 14, which now has a concrete seam to work with.

- **How to benchmark an engine that busy-spins.** Surfaced by ticket 01: Simplx
  pegs one core per node at 100% whether or not there is work, so throughput is
  bounded by loop iterations rather than by work done. The repo already has
  `benches/` and a CodSpeed workflow. Needs settling before the benchmark
  milestone, or M11 measures the spin loop.

## Out of scope

<!-- ruled beyond the destination; closed, never graduates -->

- **Concrete technical design decisions** — event schema format (JSON Schema vs
  Protobuf), integer scaling width and convention, Simplx actor topology,
  storage engine, API shapes. These belong to the build effort. The route says
  *"build: canonical event schema, abstract clock, seeded replay"*; it does not
  pick the serialisation format.
- **Writing CrashLab code**, beyond throwaway spikes taken to answer a ticket
  (e.g. compiling a Simplx tutorial to see if it works).
- **Team and parallelisation planning.** Solo. The subject's 3–5 person
  recommendation is noted and ignored.
