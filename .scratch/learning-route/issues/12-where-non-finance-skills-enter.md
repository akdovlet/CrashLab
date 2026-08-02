# Where the non-finance skills enter the route

Type: grilling
Status: open
Blocked by: 07

## Question

The route carries three learning surfaces, not one. Modern C++ has its own
ticket (06). Finance has three reading lists. This ticket places everything else.

**The skills with no home yet:**

- **Python asyncio.** Event loops, `async`/`await`, tasks, bounded queues and
  explicit backpressure — the subject demands the last of these by name in M3.
  Learned just-in-time before Exchange B, or earlier if B comes first?
- **Testing discipline.** The subject requires ≥50% line coverage (below which
  the grade caps at 75) and specifically demands **property-based tests** that
  generate order sequences and check invariants. Property-based testing is a
  genuinely different way of thinking from example-based testing and cannot be
  picked up in an afternoon. It is also unusually well suited to a matching
  engine, where the invariants are crisp and stated (no fill exceeds remaining
  quantity; a cancelled order never fills; `best_bid < best_ask` after every
  atomic transaction; the ledger reconciles at every checkpoint). Does it get
  its own step?
- **Benchmarking and latency measurement.** M11 requires count/min/mean/p50/p95/
  p99/p99.9/max across five paths, and requires optimisations to be measured
  before and after with identical functional results. Partly covered by the risk
  reading list (ticket 05) on the statistics side; the harness-construction side
  is unplaced. Note the repo already has a CodSpeed plugin configured and
  `docs/codspeed.md` present — worth deciding whether that is part of the route.
- **Docker and Compose.** Required for reproducible deployment. Probably
  incidental rather than a learning objective, but say so explicitly.
- **Event sourcing and append-only logs.** M0 demands an append-only journal
  permitting complete reconciliation, plus `event_id` / `causation_id` /
  `correlation_id` / `sequence` on every event. This is a real architectural
  pattern with real literature. It may deserve promotion out of "incidental"
  into a first-class concept — arguably it belongs in the concept graph rather
  than here.
- **Schema / IDL work.** JSON Schema or Protobuf, generating or validating
  across C++, Python and TypeScript. Skill or incidental?

**The framing question:** which of these are *learning objectives* the route
should teach deliberately, and which are *tools* to be picked up as needed and
not dignified with a step? Getting this wrong in either direction is costly —
treating property-based testing as incidental means never really learning it;
treating Docker as a learning objective wastes a week.

**Blocked because:** the placement depends on build order (ticket 07). If
Exchange B comes first, asyncio moves to the front of the route; if A comes
first, it lands in the middle.
