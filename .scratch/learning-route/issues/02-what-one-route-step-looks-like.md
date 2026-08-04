# What one route step looks like on the page

Type: prototype
Status: closed — **format settled; a step is capped, and the cap splits milestones**
Blocked by: —
Deliverable: [`research/02-route-step-prototype.md`](../research/02-route-step-prototype.md)

## Question

The route document is the destination, so its format is not cosmetic — it
determines what the other tickets have to produce. Write **one complete step at
full fidelity** and react to it.

Use **M1, the Binance oracle**, as the subject: it is small, concrete, has real
finance content (reference price vs mid vs last vs mark), has crisp acceptance
criteria, and maps cleanly onto soutenance question 1 ("why must Binance's price
never be injected directly into the local book?").

The shape agreed during charting:

```
Step N — <milestone> <title>
  build:  <the code this step produces>
  learn:  <concepts to understand first>
  read:   <named sources, with what to take from each>
  gate:   <the subject's acceptance criteria>
  gate:   <soutenance question(s), answered cold>
```

Questions the prototype has to settle:

- How long is a step? One page, or three? A step that takes two weeks of work
  described in six lines is useless; a step described in five pages is a
  document nobody re-reads.
- Does `read:` carry *what to extract* from each source, or just a citation?
  ("Harris ch. 5 — take: why price-time priority is the default, and what
  pro-rata changes" vs "Harris ch. 5".)
- Do steps carry a time estimate? With no deadline the argument for them is
  weak, but "this step is three times bigger than the last" is genuinely useful
  information.
- Is there a place for "what you will get wrong here" — the known traps, e.g.
  float in the ledger, double-counting fills after a reconnect?
- Do steps 1:1 onto the subject's milestones, or can one milestone span several
  steps (M4 — perpetual, margin, funding, liquidation — is plainly several) and
  can several milestones collapse into one?

## Answer format

The prototype step itself, saved alongside this ticket, plus the format rules it
settles.

---

## Answer (2026-08-04) — **format settled**

Prototype: [`research/02-route-step-prototype.md`](../research/02-route-step-prototype.md)
— M1 written at full fidelity (Step 3), its sibling at spine fidelity (Step 4), and
the rules in Part 3.

**The five questions, answered:**

1. **Length.** Two layers, capped by measurement rather than taste: spine
   (`after`/`build`/`learn`/`read`) **≤ 65 lines / ~650 words**, whole step
   **≤ 150 lines / ~1,500 words**. The full M1 step measures 63 and 143 — at the cap,
   not under it.
2. **`read:` carries the extract**, one line per source, plus a citation into the
   research docs — never a summary of them. Consequence: the research documents'
   section numbers (`§F2`, `§1C.2`, `§3.2`) are now an interface and must stay
   stable.
3. **Time estimates: split.** `read:` in **hours** (the research tickets measured
   them, and reading is the honest majority of a step's cost); build in **multiples of
   Step 3**, never hours.
4. **"What you will get wrong here": yes — `traps:`, the highest-value field.** Every
   trap in the prototype comes from a closed ticket, not from imagination.
5. **Steps are not 1:1 with milestones, and the length cap decides it.** Steps are
   numbered independently and milestone-tagged (`Step 3 — M1 · …`) so grading
   traceability survives. The check that keeps splitting honest: **every acceptance
   criterion of a milestone appears in the `gate — subject` of exactly one of its
   steps** — in none is a route bug, in two is a boundary in the wrong place.

**Three fields the ticket did not ask for**, each earned by the M1 write-up:
`after:` (real prerequisites, not list order — where ticket 09's dependency graph
attaches), `demo:` (one command, one observable outcome; also the anti-drift check on
`size:`), and **`forces:` — the decisions a step makes irreversible.** The map rules
concrete design decisions out of scope and they stay out, but *naming where a decision
becomes unavoidable* is what a route is for. M1 forces four, including one the subject
never assigns at all: **the oracle has no language.** C++17 is assigned to Exchange A,
Python to Exchange B, and the oracle — its own top-level directory in the recommended
tree — is assigned nothing.

**Rejected:** hours on the build side; a per-step `risk:` field (contingencies live in
the map's decisions); per-step "why this order" prose (that is the route's
introduction, written once).

**M1 is two steps**, which is the finding that made the cap a rule rather than a
preference: the feed and normalisation fill a step on their own, and the state machine
plus recording plus replay determinism is a second one carrying its own reading and
its own traps.
