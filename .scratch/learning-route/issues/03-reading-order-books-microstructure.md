# Reading list: order books and market microstructure

Type: research
Status: resolved
Blocked by: —

## Question

Find the sources that actually teach the mechanics CrashLab's M2 and M3 require,
for a strong programmer with no finance background.

**Concepts that must be covered:**

- Limit order books: price-time priority, why time priority exists, what
  pro-rata matching changes.
- Order types and lifecycle: limit, market, cancel, cancel/replace, partial
  execution, the residual. The subject mandates the state machine
  `CREATED → PENDING_NEW → LIVE → PARTIALLY_FILLED → FILLED` and it should be
  clear *why* each state is needed rather than merely copied.
- Maker vs taker, the spread, depth, what "the book is thin" costs.
- The four prices the subject insists must never be confused: **reference
  price** (external oracle), **local mid** (best bid/ask), **local last traded
  price**, and **mark price**. This distinction is the entire pedagogical
  payload of the project — soutenance questions 1 and 2 both target it.
- Adverse selection and inventory risk, enough to make M6's market maker make
  sense.
- Why exchanges publish L2 snapshots and incremental updates, and how the two
  are kept consistent.

**Selection criteria** — prefer primary and high-trust sources: standard
textbooks (name specific chapters, not whole books), exchange documentation that
specifies real matching rules, and papers where they are clearer than the
secondary literature. Reject blog posts that hand-wave the mechanics. For each
source say **what to take from it** and roughly how long it takes.

Note explicitly which sources are worth *buying* versus freely available.

## Answer format

An annotated reading list, ordered so that each item is comprehensible given
the ones before it. Flag which items are prerequisites for M2 versus which are
useful-but-deferrable.

## Answer

Resolved. Full deliverable: `../research/03-order-books-microstructure.md`
(736 lines) — ~20 sources in six ordered stages.

**Prerequisite before M2: ~28–32 hours, and exactly one book to buy** (Harris,
*Trading and Exchanges*, chapters 2/3/4/6). Everything else on the M2 path is
free. A deferrable tier is mapped per-milestone for M5, M6, M7 and M8.

**Four findings that change how the route should teach this:**

- **The subject's mandated order state machine is FIX.**
  `CREATED → PENDING_NEW → LIVE → PARTIALLY_FILLED → FILLED` with
  `PENDING_CANCEL → CANCELLED` is FIX 4.4's `OrdStatus` set renamed. FIX 4.4
  Appendix D, "Order State Change Matrices", is freely readable and gives 12
  scenario groups that explain *why* each pending state exists rather than
  merely listing them. The route should teach the state machine as FIX, not as
  an arbitrary diagram from the subject.
- **Soutenance Q3 ("how do you prevent a double fill after a retry?") has a
  verbatim primary-source answer.** Nasdaq OUCH 5.0 §1.2 states inbound messages
  "may be repeated benignly" and that `UserRefNum` "must be both unique and
  strictly increasing… the system ignores new order requests identified with
  UserRefNums lower than the last one processed, assuming they are
  retransmissions." A strictly-increasing sequence number per producer is cheap
  enough for the critical path — and the subject already mandates a monotone
  `sequence` field per producer.
- **Soutenance Q2 was, in effect, written by BitMEX.** Their "Fair Price Marking"
  page documents precisely CrashLab's A-vs-B experiment — Last Price marking vs
  Fair Price marking — with the stated rationale of avoiding liquidation caused
  by illiquid markets or manipulation. One instructive divergence: BitMEX gates
  its basis update on *spread width*, whereas CrashLab's Exchange B gates on
  *magnitude* via `clamp`. Same intent, different guard — good soutenance
  material.
- **The matching-rule disagreements are real, and there are more than expected.**
  Four venues, four different same-price allocation rules: Nasdaq is
  price/**display**/time (Rule 4757); CME Globex is configurable FIFO/Pro-Rata/
  Split with TOP, LMM and a mandatory **Leveling** step (needed because
  pro-rata's `floor()` does not conserve quantity); Eurex uses time / pro-rata
  sorted by size — *different from CME's* — and time-pro-rata; Deribit is pure
  price-time. Gould et al. §III.D adds a fifth (price-size). Price-time is a
  *choice*, not a law, and this is where the learning is.

Also documented: **two incompatible L2 snapshot/incremental consistency
contracts** — Binance uses an out-of-band REST snapshot with `(U, u, pu)` gap
detection and restart-on-gap; Coinbase delivers the snapshot in-band on a
guaranteed-delivery channel. The choice for Exchange B's `WS /stream` should be
deliberate rather than inherited.

**Honesty flags:** Foucault et al. chapter numbers differ between editions and
the publisher pages blocked verification; Bouchaud et al. Part VII chapter
numbers unverified; O'Hara's *Market Microstructure Theory* **excluded** because
its chapter titles could not be verified from any readable source; WK Selph's
much-cited "How to Build a Fast Limit Order Book" **excluded** because every
copy is dead or empty and the agent declined to recommend something it had not
read; Ho & Stoll (1981) page range disputed across databases.
