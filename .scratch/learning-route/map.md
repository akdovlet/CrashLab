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
- **How the route handles a Simplx failure.** If Simplx cannot be made to work,
  the entire Exchange A branch needs a different shape. Can't be specified until
  we know. (Partly graduated: the determinism half is now ticket 14.)

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
