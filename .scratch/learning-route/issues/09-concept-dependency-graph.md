# Concept dependency graph

Type: grilling
Status: open
Blocked by: 03, 04, 05

## Question

Once the three reading lists exist, they will contain far more concepts than the
route has steps. This ticket turns a pile of concepts into an **order**: which
idea must be understood before which other idea, and which build milestone each
one unlocks.

The output is a dependency graph, and it is the spine of the route document.
Every step's `learn:` block is a cut through this graph.

**What has to be worked out:**

- **True prerequisites vs. convenient groupings.** You cannot understand mark
  price without understanding what a last traded price and an index price are.
  But do you need funding before liquidation? The subject's own milestone order
  bundles them into M4 together — is that a real dependency or just packaging?
- **Where finance and systems concepts interlock.** Idempotency (a systems idea)
  is what makes "a trade_id can only be applied once" (a ledger invariant)
  possible. Determinism (systems) is what makes the crash scenario reproducible
  (finance). These are not two separate graphs.
- **The concepts that only make sense in combination.** The project's thesis —
  a correct engine producing systemic risk — requires holding mark price, margin,
  leverage distribution, book depth and feedback loops in mind *at once*. That
  is a single conceptual gate, not five, and the route must place it deliberately.
- **What can be deferred.** Options (M9) and KYC (M10) are late and largely
  self-contained. Anything else that can float?
- **The leverage distribution.** The subject ships a percentile table for
  drawing agent leverage and insists it is pedagogical data, not a market
  measurement. Understanding *why* the shape of that distribution creates
  clustered liquidation thresholds is a specific concept with a specific place
  in the graph — it is what makes M5 and M7 connect.

**Use `/domain-modeling` here.** The subject already supplies a vocabulary —
reference price, local mid, local last, mark price, initial margin, maintenance
margin, equity, notional, open interest, funding, premium, basis, slippage.
Pinning that vocabulary down precisely *is* half of this ticket, and confusing
any two of those terms is, in the subject's words, a design error.

**What this ticket must settle:** an ordered concept graph with each concept
tagged by the milestone it unlocks, ready to be sliced into the route's steps.

---

## Inputs now available (tickets 03, 04, 05 all resolved)

Specific things the three reading lists surfaced that this ticket should place
in the graph:

- **The mark-price spectrum** (from ticket 04): dYdX → BitMEX → OKX →
  Exchange B → Hyperliquid → Binance → Exchange A, ordered by how much the local
  book is allowed to contribute. Three robustness techniques are named —
  **exclusion, bounding, out-voting** — plus BitMEX's orthogonal **quality
  gate**. This spectrum is probably a single conceptual node placed late, and it
  is what makes the whole A-vs-B experiment legible rather than arbitrary.
- **The order state machine is FIX 4.4** (ticket 03), so it should be taught as
  a standard with reasons, not as a diagram from the subject.
- **Idempotency has a primary source** (ticket 03, Nasdaq OUCH §1.2) and the
  subject already mandates the monotone `sequence` field that implements it.
  Confirms idempotency sits early, alongside determinism, as a systems concept
  that a financial invariant depends on.
- **Liquidation rate limiting** (ticket 04) is an anti-cascade device that is
  *not* in the subject. Decide whether it enters the graph as a concept or stays
  a bonus experiment for M7.
- **Basel backtesting** (ticket 05) would add a "validate the model" node after
  the "compute VaR" node in M8. Currently absent from the subject.
- **Binance's public liquidation stream undercounts** (ticket 04) — this is an
  observability concept, and it is the sharpest available answer to soutenance
  Q5. Note it needs no code; it is pure understanding.

Also note the three lists **overlap deliberately**: mark price appears in both
03 (stage F) and 04 (block 1C), and slippage appears in both 04 and 05. The
graph is where that duplication gets resolved into single nodes.
