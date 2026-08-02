# Reading list: perpetuals, margin, funding and liquidation

Type: research
Status: resolved
Blocked by: —

## Question

This is the heart of CrashLab. M4 alone is 15 points, M7 (the cascade) is 10, and
the project's whole thesis — *a matching engine can be technically correct and
still produce systemic risk if its mark price is badly designed* — lives here.
Find the sources that teach it.

**Concepts that must be covered:**

- What a perpetual future is, why it exists, and how it stays tethered to spot
  without ever expiring. Linear vs inverse settlement; the subject uses a linear
  BTC-USD-PERP settled in simulated USD.
- **Funding**: the mechanism, who pays whom and why, how the rate is derived
  from the premium, why it is clamped. The subject's formula is
  `premium = (local_perp_mid - reference_price) / reference_price` then
  `funding_rate = clamp(k * premium, ±max_funding)`.
- **Margin**: initial margin, maintenance margin, equity, wallet balance,
  unrealised PnL, notional, and how leverage ties them together. Soutenance
  question 4 asks for the difference between initial margin, maintenance margin
  and equity, cold.
- **Liquidation**: the trigger condition
  (`equity <= maintenance_margin + estimated_liquidation_fee`), partial before
  full liquidation, why liquidation orders go through the book like any other
  order, and how slippage can drive an account negative.
- **Insurance funds and socialised loss** — what happens to the residual when an
  account goes bankrupt. Auto-deleveraging (ADL) as the mechanism real exchanges
  use, even though the subject does not require it.
- **Mark price design**: why real exchanges mark against an index rather than
  their own last trade, what an index price is composed of, what a clamped
  basis/premium does. Exchange A deliberately uses `mark = local_last_traded`
  and Exchange B uses `reference + clamp(EMA(local_mid - reference), ±max_basis)`
  — find sources that explain why the first is dangerous.
- **Liquidation cascades**: the feedback loop where liquidation orders push the
  price that triggers more liquidations. Documented real-world episodes are
  ideal here — a post-mortem of an actual cascade is worth more than any
  textbook chapter.
- **Open interest** and why it alone cannot predict liquidations — soutenance
  question 5 asks exactly this. The answer involves leverage distribution and
  entry prices, which is why the subject ships a leverage percentile table.

**Sources to prefer**: exchange documentation is unusually good here — Binance,
Deribit, BitMEX and dYdX all publish detailed margin, funding and liquidation
specifications, and these are primary sources describing systems that actually
run. Supplement with post-mortems of real cascade events and with academic work
where it clarifies rather than obscures.

## Answer format

An annotated reading list ordered for comprehension, with what to extract from
each. Separate "must understand before writing M4" from "read to understand M7".
Flag any place where different exchanges make genuinely different design
choices — those disagreements are where the learning is.

## Answer

Resolved. Full deliverable: `../research/04-perpetuals-margin-liquidation.md`
(1022 lines), ~30 sources. **Only one paid item in the entire list** (Hull, two
chapters); everything else is free.

Structure: **Phase 0** vocabulary floor (~2 h) → **Phase 1, must understand
before implementing M4** (~16–18 h, in four blocks: perpetuals and funding /
margin and the liquidation trigger / mark price and index / bankruptcy,
insurance funds, ADL and socialised loss) → **Phase 2, read to understand M7**
(~14 h: cascade theory plus real post-mortems).

**Exchange B's mark-price formula already exists in production, twice.** OKX's
mark price is literally `index + MA(mid − index)` — Exchange B without the
clamp. Hyperliquid's first mark-price input is `oracle + EMA₁₅₀ₛ(mid − oracle)`,
the same formula with a published time constant and an EMA update rule that is
correct for *irregular* sample intervals — worth copying verbatim, because an
event-driven engine never samples on a fixed grid. BitMEX's *Last Price
Protected* mode is a clamp of exactly Exchange B's shape, and it supplies a
defensible value for `max_basis`: **one maintenance margin**.

**The mark-price spectrum is the M7 report's thesis in a single line:** dYdX
(pure oracle, zero local input) → BitMEX perps (index + funding basis) → OKX →
Exchange B → Hyperliquid → Binance (median including last) → Exchange A (last
price alone). Three named robustness techniques fall out — **exclusion**,
**bounding**, **out-voting** — plus an orthogonal fourth from BitMEX: a
**quality gate** that stops refreshing the basis when the book is wider than one
maintenance margin. That gate is precisely the M7 condition, and it is a
two-line addition.

**The 10–11 October 2025 Binance USDe/BNSOL/WBETH event is the Exchange A loop
run for real, with a ~$283M invoice** — collateral valued from Binance's own
thin spot books, forced liquidations, and a remedy (external redemption prices
plus a floor on the index) that is Exchange B applied after the fact. Sourced to
Binance's own posts; the causal claim about the pre-incident index is Ethena's
characterisation and is flagged as such in the deliverable.

**§5, the disagreements** — six comparison tables: mark price, funding formula
(four incompatible ones), liquidation execution (five), margin schedule
(flat/tiered/OI-scaled), who eats the bad debt (five), insurance-fund scope
(four). Sharpest single disagreement: **dYdX deleverages against a *randomly
chosen* counterparty while everyone else ranks by profit × leverage.**

**Most underrated implementable idea: liquidation rate limiting.** Hyperliquid
caps at 20% per attempt with a 30-second cooldown; dYdX uses per-block caps.
This is an explicit anti-cascade device, and it is a real M7 experiment — run
the cascade with it and without it. Strong candidate for the route.

**On soutenance Q5**, the strongest point turned out to be about observability
rather than theory: **Binance's public liquidation stream pushes only the
largest order per symbol per second**, so every public liquidation figure
undercounts — and undercounts worst exactly during a cascade, when the data
matters most.

**Honesty flags (§7):** BitMEX `/app/*` pages are JS-rendered and were verified
against 2019 archives, so structure is reliable but **numbers will have
changed**; no official post-mortem exists for dYdX/YFI (Nov 2023) or
Hyperliquid/JELLY (Mar 2025), both flagged as weak sourcing; two arXiv items are
unreviewed preprints; Deribit's exact linear-perp mark construction could not be
verified and was **not guessed**. The agent also corrected itself mid-draft on a
legal fact — the Mango convictions were vacated by the *trial judge* on a Rule 29
motion in May 2025, not on appeal, and prosecutors have appealed that acquittal.
