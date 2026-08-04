# What one route step looks like on the page — prototype

Deliverable of [`issues/02-what-one-route-step-looks-like.md`](../issues/02-what-one-route-step-looks-like.md).

**This is a prototype: throwaway.** Part 1 is one step written at full fidelity, on
M1 (the Binance oracle). Part 2 is a spine-only sketch of its sibling step, there to
show the two fidelity levels side by side. Part 3 is the format rules the exercise
settles, which is the part that graduates into the route document. When the route is
written, Part 1 gets rewritten in place and this file stops being authoritative.

The headline finding, up front, because it reframes two of the ticket's five
questions into one:

> **A step's length is not a style preference — it is the definition of a step.**
> Set the cap, and the cap does the milestone-splitting for you: M1's material does
> not fit in one step, so M1 is two steps. No separate rule about whether steps map
> 1:1 onto milestones is needed; the cap is the rule.
>
> Measured on Part 1 rather than guessed: **spine 63 lines / 650 words, whole step
> 143 lines / ~1,450 words.** That is the cap — two screens, about three printed
> pages — and Part 1 sits at it, not under it.

---

## Part 1 — the step, at full fidelity

### Step 3 — M1 · The oracle feed: BTC/USDT, read-only

**after:** Step 1 (M0 canonical schema — `ReferencePriceUpdate` is the first message
through it) and Step 2 (M0 abstract clock — `received_ts_ns` must come from it, or
this step's recording is unreplayable). Nothing else. This is the first step that
produces a running process.

**build:**

- A read-only price service on Binance's public BTCUSDT stream, publishing
  `ReferencePriceUpdate { exchange_ts_ns, received_ts_ns, bid_px, ask_px,
  reference_px, status }` — the struct is given verbatim in the subject, §5 M1.
- Public REST used at start-up and as fallback only, never as steady state.
- Decimal-string → scaled `int64` normalisation, with the scale factor a schema
  constant and a round-trip test over it.
- Two timestamps from two different clocks, carried separately and never mixed.
- `status` populated as `LIVE` only; the rest of the state machine is Step 4.
- No API key, no signed endpoint, no order endpoint anywhere in the tree.
- The first half of `make record-oracle`.

**learn** (before writing a line):

- **The four prices, and why they are four.** Reference moves with no local event at
  all; local mid moves on any book event *including a pure cancel*, and is undefined
  when a side is empty; local last moves only on a local trade and is stale by
  construction between trades; mark is a *policy*, not an observation. The project is
  the disagreement between two such policies.
- **An index price is a construction, not an observation** — constituents, weights,
  deviation caps, connectivity rules, failover. A single-feed oracle is the
  degenerate one-constituent case of exactly that machinery. This framing is what
  makes the M1 write-up more than a changelog.
- **Why `bid_px`/`ask_px` are in the struct next to `reference_px`.** Because
  `reference_px` is derived, the derivation is a choice, and the divergence control
  in M7 compares *your* mid against this one.
- **Three clocks in one struct.** `exchange_ts_ns` is a third party's wall clock —
  adjustable at any moment, and not yours. `received_ts_ns` is your clock, and in
  replay it is not a clock at all but a counter. Mixing them should be a type error,
  not a convention.
- **The replay ground rule**: in replay the recording is the only input, and the code
  must not notice that the network is unreachable.

**read** (≈ 4 h, everything free; ≈ 5.5 h if the chrono tutorial wasn't done at M0):

- `research/03 §F2` — Binance Index Price / Mark Price docs. *Take:* the index is a
  weighted average over *external* venues, built so no single venue's book can move
  it. Record the date you read it; Binance revises these formulas.
- `research/03 §F3` — write the four-prices one-pager yourself (~1 h). *This is the
  step's understanding artefact*: it is what you will actually say at the soutenance,
  and no source can write it for you.
- `research/04 §1C.2` — Binance index construction, ~20 min of it. *Take:* the
  deviation cap and the connectivity rule (a venue offline ≥ 5 min gets zero weight).
  Your LIVE/STALE/DISCONNECTED machine is that connectivity rule with N = 1.
- `research/03 §D2` — Binance "How to manage a local order book correctly". You are
  not mirroring Binance's book, so read it for one idea only: a feed must let its
  consumer *detect a gap*, and the response to a gap is resynchronise, not repair.
  Then ask what gap detection your own `ReferencePriceUpdate` offers a consumer. The
  answer is *none* — see **forces**.
- `research/05 §F8b` — CFTC v. Eisenberg (Mango Markets), press release, 30 min.
  *Take:* an oracle-manipulation enforcement action with a real number on it — MNGO
  driven 13× in ~30 minutes, $110m withdrawn. Read it here rather than at M7: it is
  *why this step exists*.
- `research/06 §3.2` — Hinnant's chrono tutorial, 1.5 h, if not already done at M0.
  *Take:* mixing clocks is a type error. This struct has three clocks in it.

**traps** (what you will get wrong here):

- **Float in the parser, not just in the ledger.** Binance sends prices as decimal
  *strings* specifically so you need not touch a `double`. Parsing `"63251.10"` to
  `double` and multiplying by 1e8 can land on `6325109999`. Parse string → integer
  directly, and test the round trip on values with trailing 9s.
- **Treating `exchange_ts_ns` as ordering truth.** It is a third party's wall clock.
  Order by receipt, keep the source timestamp as data, and expect
  `received − exchange` to go negative under clock skew — that must not fire an
  assert.
- **Wiring the reference price into anything matching can see.** Seeding the local
  book from the oracle "just for testing" is convenient, becomes permanent, and is
  precisely what soutenance Q1 asks about. Structural guard: the matching engine's
  build target must not link the oracle's types at all.
- **A reconnect that silently changes the stream's meaning.** After a reconnect you
  have a *new* stream; its first message is not a continuation of the old one.
  Publishing it as though nothing happened hides exactly the gap D2 is about.
- **Recording the wrong clock.** Record `received_ts` from a wall clock while replay
  drives from a counter and the recording is unreplayable — which you discover in
  M0's functional-hash test, three milestones later.
- **`std::string` in an event payload, if this ever crosses into Simplx.** From
  ticket 01: destructors are never run on events, and a short string hides inside
  the SSO buffer, so it passes every test and then leaks 172 bytes per event once an
  ID grows past 15 characters. `ReferencePriceUpdate` is all `int64` plus an enum —
  keep it that way and assert `is_trivially_destructible` on the payload.

**forces** (decisions this step makes irreversible, named but not made here):

- **What language the oracle is written in.** The subject assigns C++17 to Exchange A
  and Python to Exchange B, and says nothing at all about the oracle.
- **What `reference_px` actually is** — `bookTicker` mid, aggregate-trade last, or
  both published with the reference being the mid. The struct has room for all three.
  You will defend the choice in the M7 report.
- **Your own feed's gap-detection contract.** The given struct has no sequence
  number. If consumers cannot detect a dropped update, the feed is not correct no
  matter how correct the source is.
- **Scale factor and integer width.** 8 decimals of a BTC price sits comfortably in
  `int64`; the same convention applied to notional × leverage may not. M1 is where
  the number is first written down.

**gate — subject** (§5 M1, and the M0 criteria that carry):

- Public WebSocket BTCUSDT feed (best bid/ask or aggregate trade) running.
- Public REST used only for initialisation, health check or fallback.
- No trading authentication and no order endpoint.
- Normalisation to an integer price; source and receipt timestamps both carried.
- No secret committed (M0, carried); no trading key or real identity data
  (§ validation checklist, *Sécurité*, carried).
- *Deferred to Step 4:* staleness detection, reconnect with backoff, heartbeat,
  compact recording and offline replay — and the *Oracle* row of the validation
  checklist ("live, stale, disconnect and replay demonstrated"), which needs both
  steps.

**gate — understanding** (answered cold, without opening the code):

**Soutenance Q1 — why must Binance's price never be injected directly into the local
book?** A passing answer names three things: (1) the local book would then have no
independent price, so basis, funding and the whole cascade would be zero *by
construction* and the A/B experiment would measure nothing; (2) the local venue would
inherit a third party's failure modes as its own trading truth; (3) a price source
that can be pushed is a documented attack surface, not a hypothetical — Mango
Markets, ~$110m. The answer that shows real reading adds the nuance: the discipline is
not "external price is forbidden" but **"no single source may dominate"** — Binance's
own mark price takes a median of three inputs, one of which *is* the contract's own
price. Exchange A's sin is not using the local price; it is using it *alone*.

Self-check, not on the soutenance list but the same knowledge: what does your oracle
publish when one side of the book is momentarily empty?

**demo:** `make record-oracle` for 60 s produces a recording; the recording replays
with the network unreachable and emits byte-identical events.

**size: 1×.** This is the route's unit step, and the anchor every other step is
measured against — roughly one evening of building once the reading is done, assuming
M0's clock and schema are real. (Reading is costed in hours because the research
tickets measured it; building is costed in multiples of this step because nobody can
honestly estimate it in hours for work they have not done before.)

---

## Part 2 — the sibling step, spine only

Included to show what a step looks like *before* it has been written out, and to make
the split concrete.

### Step 4 — M1 · Oracle states, recording and offline replay

- **after:** Step 3.
- **build:** `LIVE / STALE / DISCONNECTED / REPLAY` state machine on
  `OracleStatus`; staleness threshold derived from the feed's own heartbeat;
  reconnect with bounded backoff; compact append-only recording; a replay source that
  is a drop-in for the live source.
- **learn:** deviation-threshold-*or*-heartbeat as an update model; why the correct
  response to staleness is *pause or degraded mode*, never *ignore the state*; why
  the state machine belongs to the oracle and the *policy* belongs to its consumers.
- **read:** `research/05 §F8a` (Chainlink, "check the timestamp of the latest
  answer" — the threshold "should correspond to the heartbeat of the feed", ~45 min);
  `research/04 §1C.2` connectivity rule again, now as the thing you are implementing;
  `research/06 §2.6` (FoundationDB deterministic simulation — why the abstraction has
  to be *total*: one un-abstracted `now()` and the property is gone).
- **traps:** staleness measured against your clock instead of against the source
  timestamp; backoff without jitter; a recording that stores formatted text and so
  cannot round-trip exactly; `REPLAY` treated as a fifth transport rather than as a
  clock substitution.
- **gate — subject:** staleness detection, reconnect with backoff, heartbeat, compact
  recording, offline replay; validation checklist *Oracle* row demonstrated end to
  end; `make replay SEED=42` produces the same functional hash on the oracle stream.
- **gate — understanding:** contributes to Q10 (*which of your model's assumptions is
  most fragile?*) — a single-constituent index with a threshold you chose is a
  candidate answer, and this is the step where you learn why.
- **size:** 1×.

---

## Part 3 — the format rules this settles

### The five questions the ticket asked

**1. How long is a step?** Two layers, each with a measured cap. A **spine** —
`after`, `build`, `learn`, `read` — of **≤ 65 lines / ~650 words**, which is the
re-read surface and fits one screen. Then **notes** — `traps`, `forces`, both gates,
`demo`, `size` — read once, when the step starts, and skimmed thereafter. Whole step
**≤ 150 lines / ~1,500 words**, about three printed pages. Part 1 measures 63 and 143:
it sits *at* the cap, which is the useful place for a worked example to sit.

**A step that overflows the cap is two steps.** M1 is the proof: Step 3 alone fills
the budget, and Step 4's material — a four-state machine, backoff, an append-only
recording, replay determinism, with its own reading list and its own traps — would
roughly double it. The split is forced by the material, not chosen for tidiness.

The cap is load-bearing: it is the only mechanical check in the whole format, and it
does the work that three other rules would otherwise have to do. It is a ceiling, not
a target: nothing is padded up to it.

**2. Does `read:` carry what to extract?** **Yes, one line of extract per source —
and a citation into the research docs, never a summary of them.** The route sequences
the reading; the research docs hold it. Duplication here would drift within a month.
Cost of this rule, stated plainly: it makes the research documents load-bearing, so
they need **stable section anchors** (`§F2`, `§1C.2`, `§3.2`). Ticket 03/04/05/06's
deliverables already number their sections; that numbering is now an interface and
should not be renumbered casually.

**3. Do steps carry a time estimate?** **Split the question.** `read:` carries
**hours**, because the research tickets actually measured them and they are the
honest majority of a step's cost. Build carries a **multiple of Step 3**, never
hours — a solo developer cannot estimate hours for work they have never done, and a
wrong hour figure gets treated as a deadline even when the map says there is no
deadline. "This step is three times the oracle step" is the useful signal, and it
survives being wrong.

**4. Is there a place for "what you will get wrong here"?** **Yes — `traps:`, and it
is the highest-value field in the format.** Every trap in Part 1 comes from a closed
ticket rather than from imagination: the SSO-hidden event leak and the
trivially-destructible rule are ticket 01's findings; resynchronise-don't-repair is
`research/03 §D2`; the clock rules are `research/06 §2.6`. This field is where the
research pays out. If a step has no traps, that is a signal the reading for it has not
been done yet, not that the step is easy.

**5. Do steps map 1:1 onto milestones?** **No, and the length cap decides it, not
taste.** Steps are numbered independently and tagged with their milestone
(`Step 3 — M1 · …`) so that grading traceability survives. Splitting is expected: M1
is 2, M4 (perpetual, margin, funding, liquidation) will plainly be 4 or more. Merging
is allowed only when several milestones share one gate. **The check that keeps
splitting honest:** every acceptance criterion of a milestone must appear in the
`gate — subject` of exactly one of its steps. A criterion in none of them is a route
bug; a criterion in two is a step boundary in the wrong place. Part 1 does this
explicitly with its *Deferred to Step 4* list.

### Rules the prototype added that the ticket did not ask for

- **`after:` — real prerequisites, not list order.** The route is a sequence, but the
  dependency is the fact; ordering is just one valid linearisation of it. This field
  is where ticket 09's concept-dependency graph attaches to the route.
- **`forces:` — decisions the step makes irreversible.** The map rules concrete
  technical design decisions out of scope, and they should stay out — but *naming
  where a decision becomes unavoidable* is exactly what a route is for. M1 forces
  four, including one the subject simply never assigns (what language the oracle is
  written in). Without this field that gap surfaces during implementation, which is
  the worst moment to find it.
- **`demo:` — one command, one observable outcome.** Every step ends with something
  runnable. It is also the anti-drift check on `size:`: if you cannot name the demo,
  the step is not one step.
- **Empty fields are omitted, not stubbed.** `— none —` lines are how a
  seven-field format becomes unreadable. `after`, `build`, `read`, both gates and
  `size` are mandatory; `learn`, `traps`, `forces` and `demo` appear when they have
  content.
- **Understanding gates get a rubric, not a question number.** "Q1" alone is not a
  gate you can fail honestly against yourself. Part 1 writes what a passing answer
  contains and what separates it from a good one. This is the field that makes the
  route about understanding rather than delivery, so it is worth the four extra
  lines.

### Rejected

- **Hours on the build side** — see question 3.
- **A `risk:` or `if this fails:` field.** Contingencies belong in the map's
  decisions, where ticket 01's Simplx verdict already lives, not repeated per step.
- **Per-step "why this order" prose.** That is the route document's introduction,
  written once. Repeating it thirty times is how a document stops being re-read.
