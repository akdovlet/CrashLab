# Reading list — perpetuals, margin, funding, liquidation, cascades

Research answer for `issues/04-reading-perpetuals-margin-liquidation.md`.
Covers CrashLab **M4** (15 pts) and **M7** (10 pts), and soutenance questions **2**
(*"why should local last price and mark price not always be identical?"*) and **5**
(*"why is open interest alone insufficient to precisely predict liquidations?"*).

Reader assumed: strong programmer, C++98-fluent, **zero finance background**.
Optimised for depth, not speed. Everything below is either free or explicitly marked paid.

---

## 0. How to read this list

Three rules that matter more than the list itself:

1. **Exchange documentation is the primary literature here.** For perpetual futures there is
   no canonical textbook — the product was invented by an exchange (BitMEX, 2016) and its
   specification lives in exchange docs. A Binance FAQ page describing a system that clears
   tens of billions of dollars a day *is* a primary source. Treat it as a spec, not as marketing.
2. **Read at least three exchanges on every mechanism.** Any single exchange's doc reads as
   "this is how it works". Three exchanges reveal that it is a *design decision*. Section 5 of
   this document collects the places where they genuinely disagree — that section is the point
   of the whole exercise, and it is where the CrashLab thesis lives.
3. **Write the formula down in your own notation before you code it.** Every doc below uses a
   different symbol set. The subject (§M4) gives you five formulas; your job is to be able to
   place each exchange's formula next to yours and say what they chose differently and why.

Time estimates are for careful reading with notes, not skimming.

**Total for Phase 1 (before writing M4): ~18–24 hours.**
**Total for Phase 2 (before M7): ~12–16 hours.**

---

## 1. Phase 0 — vocabulary floor (~2h)

You need three words before anything else parses: *future*, *margin*, *basis*.

### 0.1 Hull, *Options, Futures, and Other Derivatives*, ch. 1 §1.1–1.4 and ch. 2 — **PAID**

- John C. Hull, *Options, Futures, and Other Derivatives*, 11th edition (Pearson, 2021).
  Verified against the 11th Global Edition contents:
  - **§2.2 Specification of a futures contract** (p. 48)
  - **§2.3 Convergence of futures price to spot price** (p. 50)
  - **§2.4 The operation of margin accounts** (p. 51)
  - **§5.12 The cost of carry** (p. 143)
  - **§5.14 Futures prices and expected future spot prices** (p. 144)
- ~2 hours for §2.2–2.4; another hour for the ch. 5 sections when you get to funding.
- **Take from it:** what a futures contract *is* as a legal/settlement object; why a
  fixed-maturity future's price converges to spot at expiry (this is exactly the thing a
  perpetual does *not* have, which is why funding must exist); and the classical margin
  account — initial margin, maintenance margin, margin call, variation margin.
- **Critical contrast to notice now and hold onto:** in Hull's world the broker issues a
  *margin call* and the client has time to wire money. In every crypto perpetual you will read
  about below, there is no call and no cure period — the engine liquidates. That difference is
  half of why cascades happen in crypto and rarely in listed futures.
- **If you refuse to buy the book:** the concepts in §2.4 are also covered adequately by the
  CFTC's consumer education glossary (below) plus BitMEX's *Margin Term Reference*
  (<https://www.bitmex.com/app/marginTermReference>). You lose the convergence argument, which
  matters — try to get ch. 2 and ch. 5 by any legitimate means.

### 0.2 CFTC Glossary — **FREE**, ~20 min

- U.S. Commodity Futures Trading Commission, *CFTC Glossary*,
  <https://www.cftc.gov/ConsumerProtection/EducationCenter/CFTCGlossary/index.htm>
  (letter pages, e.g. `.../CFTCGlossary/glossary_o.html` for *Open Interest*).
- **Take from it:** regulator-authored one-line definitions of *open interest*, *basis*,
  *initial margin*, *maintenance margin*, *variation margin*, *mark to market*, *notional value*.
  The open-interest entry — "the total number of futures contracts long or short in a delivery
  month or market that has been entered into and not yet liquidated by an offsetting transaction
  or fulfilled by delivery" — is the exact definition you will need for soutenance Q5. Notice
  what it does *not* contain: no price, no leverage, no account identity. That absence is the
  whole answer to Q5.
- *Note:* `cftc.gov` blocks scripted fetches (HTTP 403) but serves browsers normally.

---

## 2. Phase 1 — MUST understand before implementing M4

This is the block that has to be done before you write `MarginActor` / `LiquidationActor`.

### 1A. What a perpetual is and how funding tethers it (~4h)

#### 1A.1 BitMEX — *Perpetual Contracts Guide* — **FREE**, ~90 min ★ start here

- <https://www.bitmex.com/app/perpetualContractsGuide>
- Sections, in order: *Overview* → *Mechanics of a Perpetual Contract Market* → *Funding* →
  *Funding Rate Calculations* (*Interest Rate Component*, *Premium / Discount Component*,
  *Final Funding Rate Calculation*) → *Funding Rate Caps* → *Funding Fees*.
- **Why first:** BitMEX invented the instrument, and this page is the shortest complete
  statement of the design. It gives you, on one page: no expiry; tether-to-spot via funding;
  marking is a *separate* mechanism from matching; funding is peer-to-peer, not an exchange fee.
- **Take from it, verbatim:**
  - `Funding = Position Value * Funding Rate` — and the explicit note that position value is
    *irrespective of leverage*. (CrashLab's `funding_payment = position * mark_price * funding_rate`
    is the same statement.)
  - `Premium Index (P) = (Max(0, Impact Bid Price - Mark Price) - Max(0, Mark Price - Impact Ask
    Price)) / Spot Price + Fair Basis used in Mark Price`
  - `Funding Rate (F) = Premium Index (P) + clamp(Interest Rate (I) - Premium Index (P), 0.05%, -0.05%)`
    and the accompanying observation that if `|I - P| < 0.05%` then `F = I` exactly.
  - The two funding caps: absolute rate capped at 75% of (Initial Margin − Maintenance Margin),
    and rate-of-change capped at 75% of Maintenance Margin per interval.
  - Funding timestamps 04:00 / 12:00 / 20:00 UTC, and "you only pay or receive funding if you
    hold a position at the Funding Timestamp" — i.e. funding is a **discrete event**, which is a
    real, exploitable design property, not an implementation detail.
- **Directly relevant to your code:** CrashLab's funding formula
  `funding_rate = clamp(k * premium, ±max_funding)` has **no interest-rate term** and **no
  ±0.05% dampener**. BitMEX's has both. Understand what each is for before deciding your
  simplification is harmless — see §5.2.
- *Fetch note:* the `bitmex.com/app/*` pages are client-rendered; they display fine in a browser
  but return an empty shell to scripts. The content quoted above was verified against Internet
  Archive captures of the same URLs.

#### 1A.2 Deribit Insights — *Perpetual Swap Funding* — **FREE**, ~40 min

- Cryptarbitrage, *Perpetual Swap Funding*, Deribit Insights, 13 May 2020,
  <https://insights.deribit.com/education/perpetual-swap-funding/>
- **Take from it:** the clearest plain-English statement of *why* funding works as an
  economic force ("when the perp trades above index, longs pay shorts, which reduces demand for
  longs"), plus a second, different funding construction:
  - `Premium Rate = ((Mark Price − Deribit Index) / Deribit Index) * 100%`
  - a **dead-band damper** rather than an interest term: within ±0.025% the funding rate is
    forced to zero; outside it, the rate is the premium rate pulled back toward zero by 0.025%.
  - `Funding Payment = Funding Rate * Position Size BTC * Time Fraction`, with
    `Time Fraction = Funding Rate Time Period / 8 hours` — because Deribit accrues and transfers
    funding **continuously (every few seconds)**, quoting only an annualised-style 8-hour rate
    for comparability.
- **Why this matters to you:** it is the direct counter-example to BitMEX's discrete
  funding timestamps, and it settles a design question you will hit in M4 (`funding_period =
  temps simulé configurable`): continuous accrual removes the "hold through the snapshot" game
  entirely. Note the article is from 2020 and quotes ±0.5%/±1% caps; current Deribit caps
  differ by product — treat the *shape* of the formula as durable, the constants as dated.

#### 1A.3 dYdX v4 — *Funding* — **FREE**, ~30 min

- <https://docs.dydx.xyz/concepts/trading/funding>
- **Take from it, verbatim:**
  - `Funding Rate = (Premium Component / 8) + Interest Rate Component`
  - `Premium = (Max(0, Impact Bid Price − Index Price) − Max(0, Index Price − Impact Ask Price)) / Index Price`
  - `Impact Notional Amount = 500 USDC / Initial Margin Fraction`
  - the one-hour premium is a **simple TWAP of 60 one-minute premiums**; funding is charged
    **hourly**, not 8-hourly.
  - `8-hour rate cap = 600% * (Initial Margin − Maintenance Margin)`
  - Interest-rate component: **0% for cross markets**; 0.125 bps/hour for isolated markets.
- **The single most transferable idea in this section — "impact price":** all three of BitMEX,
  Binance and dYdX derive the premium from the *average fill price of a hypothetical order of a
  fixed notional*, not from the best bid/ask, and not from the last trade. This makes the premium
  a function of **book depth**, so a one-lot print at a silly price cannot move it. CrashLab's
  `premium = (local_perp_mid - reference_price) / reference_price` uses the mid, which is
  one-lot-manipulable at the top of book. This is a deliberate simplification you should be able
  to defend, and an obvious M4 stretch goal.

#### 1A.4 He, Manela, Ross & von Wachter, *Fundamentals of Perpetual Futures* — **FREE**, ~2h

- arXiv:2212.06888, <https://arxiv.org/abs/2212.06888>
- **Read:** the introduction and the no-arbitrage pricing section. Skip the empirical
  estimation unless you want it.
- **Take from it:** the formal statement that "perpetuals are **not guaranteed** to converge to
  the spot price" — funding is a *force*, not a *constraint*, and the no-arbitrage bound widens
  with trading costs. This is the theoretical licence for CrashLab's whole premise: a perp can
  and does trade away from its index, and how far it is allowed to drift before the margin system
  reacts is a design parameter (your `max_basis`).
- Read *after* 1A.1–1A.3, not before; the paper assumes you know what funding is.

#### 1A.5 (Optional, 20 min, delightful) Shiller's original perpetual future — **PAID/FREE**

- Robert J. Shiller, "Measuring Asset Values for Cash Settlement in Derivative Markets: Hedonic
  Repeated Measures Indices and Perpetual Futures", *Journal of Finance* 48(3), 1993, 911–931.
  Paywalled at Wiley; free as NBER Technical Working Paper t0131,
  <https://www.nber.org/papers/t0131>.
- **Take from it:** perpetual futures were proposed in 1993 as a way to trade illiquid indices
  (housing) by cash-settling the *dividend/rent flow* daily. The crypto funding rate is a
  rediscovery of that idea with the carry term replaced by a book-derived premium. Useful for one
  sentence of the soutenance and for realising the design space is older than crypto.

---

### 1B. Margin, equity, and the liquidation trigger (~5h)

This is soutenance question 4 territory (*initial margin vs maintenance margin vs equity*).

#### 1B.1 Binance — *Leverage and Margin of USDⓈ-M Futures* — **FREE**, ~45 min ★

- <https://www.binance.com/en/support/faq/leverage-and-margin-of-usd%E2%93%A2-m-futures-360033162192>
  and the live parameter table at
  <https://www.binance.com/en/futures/trading-rules/perpetual/leverage-margin>
- **Take from it:**
  - `Maintenance Margin = Notional Position Value * Maintenance Margin Rate − Maintenance Amount`
  - The **tiered** structure: maintenance margin rate is a step function of *notional position
    size* (roughly 0.4%–50% across tiers), and max leverage falls as the position grows.
  - The `Maintenance Amount` term exists purely to make the piecewise function *continuous* at
    tier boundaries — otherwise a trader crossing a tier boundary would see maintenance margin
    jump discontinuously and could be liquidated by a one-contract fill. This is an
    implementation subtlety worth stealing.
  - The stated invariant: maintenance margin **does not depend on the leverage you selected**,
    only on notional. Selected leverage only sets initial margin.
- **Why it matters for M4:** CrashLab specifies `maintenance_margin = notional *
  maintenance_margin_rate` with a flat rate. Every production exchange makes that rate a function
  of size. Adopting the flat rate is fine — but it removes a *stabiliser*, and you should know
  that you removed it (see §5.4 and §6.2).

#### 1B.2 Binance — *How to Calculate Liquidation Price of USDⓈ-M Futures Contracts* — **FREE**, ~45 min

- <https://www.binance.com/en/support/faq/how-to-calculate-liquidation-price-of-usd%E2%93%A2-m-futures-contracts-b3c689c1f50a44cabb3a84e663b81d93>
- **Take from it:** the full cross-margin liquidation-price formula, whose inputs are
  Wallet Balance, the maintenance margin of *all other* contracts (TMM), the unrealised PnL of
  *all other* positions (UPNL), position quantity, entry price, maintenance margin rate, and the
  maintenance amount. In isolated mode, TMM = 0 and UPNL = 0 and the formula collapses.
- **This page alone is 60% of the answer to soutenance Q5.** Read the input list and ask:
  which of these can an outside observer read off the public open-interest number? Answer: none
  of them. See §6.2.

#### 1B.3 dYdX v4 — *Margining* — **FREE**, ~45 min

- <https://docs.dydx.xyz/concepts/trading/margin>
- **Take from it, verbatim:**
  - `Total Account Value = Q + Σ (Sᵢ × Pᵢ)`  (Q = USDC balance, S = signed size, **P = oracle price**)
  - `Total Initial Margin Requirement = Σ |Sᵢ × Pᵢ × Iᵢ|`
  - `Total Maintenance Margin Requirement = Σ |Sᵢ × Pᵢ × Mᵢ|`
  - `Free collateral = Total Account Value − Total Initial Margin Requirement`
  - The open-interest-scaled IMF:
    ```
    open_notional   = open_interest * oracle_price
    scaling_factor  = (open_notional - open_notional_lower_cap) / (open_notional_upper_cap - open_notional_lower_cap)
    IMF_increase    = scaling_factor * (1 - base_IMF)
    effective_IMF   = Min(base_IMF + Max(IMF_increase, 0), 100%)
    ```
    with MMF held **fixed**.
- **Two things to extract:**
  1. This is the cleanest formal statement of the equity / IM / MM triangle anywhere in this
     list — it maps 1:1 onto CrashLab's `equity`, `initial_margin`, `maintenance_margin`.
     Memorise this shape for soutenance Q4.
  2. dYdX makes **initial margin a function of market-wide open interest**: as OI grows, it
     becomes progressively more expensive to *add* risk, while the maintenance requirement on
     existing risk is untouched. That is a direct, production-grade answer to "what would you do
     about the crowded-trade problem?" — and evidence that exchanges themselves treat open
     interest as a *systemic* signal, not a per-account one.

#### 1B.4 dYdX v4 — the actual source code — **FREE**, ~2h ★ (do this; you're a programmer)

- <https://github.com/dydxprotocol/v4-chain> (Go, Apache-2.0). Read in this order:
  - `protocol/x/subaccounts/` — how an account's collateral and positions are represented and
    how the margin check is evaluated.
  - `protocol/x/clob/keeper/liquidations.go` — the liquidation decision and the construction of
    the liquidation order.
  - `protocol/x/clob/types/liquidation_order.go` and `match_perpetual_liquidation.go` — the
    liquidation order as a first-class object that goes through the same matching path as any
    other order.
  - `protocol/x/clob/keeper/deleveraging.go` and `types/match_perpetual_deleveraging.go` — the
    last-resort path.
  - `protocol/x/clob/types/liquidations_config.go` and
    `proto/dydxprotocol/clob/liquidations_config.proto` — the parameter surface: max liquidation
    fee (ppm, 100% of which goes to the insurance fund), per-block caps on how much of a single
    position and how many quote quantums from a single subaccount may be liquidated, and how the
    fillable-price spread from the oracle widens with the subaccount's bankruptcy rating.
  - `protocol/x/perpetuals/funding/` and `protocol/x/clob/keeper/get_price_premium.go` — funding
    and premium, implemented.
- **Take from it:** this is the only place in this entire list where you can read a complete,
  production, open-source perpetual risk engine end to end. It answers questions the prose docs
  dodge: what integer type holds a price, where rounding happens, what is checked inside the
  block boundary vs. across blocks, and what happens when two liquidations race. Given CrashLab's
  "no binary floats in the ledger" constraint, the quantum/subtick integer scheme
  (`price_to_subticks.go`) is worth stealing outright.

---

### 1C. Mark price and index price — the heart of the project (~5h)

Everything in this subsection feeds soutenance Q2 and the M7 thesis. Do not skim it.

#### 1C.1 BitMEX — *Fair Price Marking* — **FREE**, ~45 min ★★ the single most important page

- <https://www.bitmex.com/app/fairPriceMarking>
- Sections: *Overview* → *Calculation of Fair Price for Perpetual Contracts* → *Calculation of
  Fair Price for Futures Contracts* → *Impact Bid, Ask, and Mid Price* → *Fair Price Derivation*
  → *Exceptions* → *Last Price Protected Marking*.
- **The overview paragraph is, essentially, the CrashLab subject stated by an exchange:**
  > "BitMEX employs a unique system called **Fair Price Marking** to avoid unnecessary
  > liquidations in its highly leveraged products. Without this system, unnecessary liquidations
  > may occur if the market is being manipulated, is illiquid, or the Mark Price swings
  > unnecessarily relative to its Index Price. The system is able to achieve this by setting the
  > Mark Price of the contract to the **Fair Price** instead of the **Last Price**."

  If you can only cite one sentence in the soutenance for Q2, cite that one.
- **Take from it, verbatim:**
  - For perpetuals: `Funding Basis = Funding Rate * (Time Until Funding / Funding Interval)`,
    `Fair Price = Index Price * (1 + Funding Basis)`. **Note what is absent: the local order
    book.** BitMEX marks perpetuals against the index and the decaying funding basis *only*.
  - For fixed-maturity futures: `% Fair Basis = (Impact Mid Price / Index Price − 1) / (Time To
    Expiry / 365)`, `Fair Value = Index Price * % Fair Basis * (Time to Expiry / 365)`,
    `Fair Price = Index Price + Fair Value`.
  - The staleness guard: the % Fair Basis is only refreshed if `Impact Ask − Impact Bid` is
    smaller than one maintenance margin (or 3 ticks). **When the book gets wide, the mark stops
    following it.** This is precisely the behaviour you want in your Exchange B during the M7
    crash, and it is a two-line addition to your EMA.
  - The explicit warning that "you may see a positive or negative Unrealised PNL immediately
    after an order executes" — because fill price ≠ mark price. Expect this in your own tests
    and don't treat it as a bug.
- **★ *Last Price Protected Marking* — read this section twice.** It is a marking mode where the
  mark price *is* the last traded price, but confined to a band of one maintenance margin
  (±0.5 MM) around the previously-computed Fair Price, and — critically — "if the band moves,
  the Mark Price will stay. It is allowed to move toward the band but not away from it."
  **This is a production exchange's version of CrashLab's Exchange B formula.** Your
  `reference + clamp(EMA(local_mid − reference), ±max_basis)` and BitMEX's
  `clamp(last, fair ± 0.5·MM)` are the same idea: *let the local price matter, but bound how far
  it can drag the margin system*. Being able to say that out loud in the soutenance is worth a
  lot. It also gives you a defensible number for `max_basis`: one maintenance margin.

#### 1C.2 Binance — *Mark Price and Price Index* — **FREE**, ~45 min

- <https://www.binance.com/en/support/faq/detail/360033525071>
  ("What Is the Difference Between a Mark Price and Price Index?" / USDⓈ-M Mark Price)
- **Take from it:**
  - `Price Index = Σ (Weight% of Exchange × Spot Price on Exchange)` over a named basket of
    external venues (CEXs and, more recently, DEX pools), with two guards worth copying:
    a **deviation cap** (a constituent more than ~3% from the median — 1% for majors — is capped
    rather than used raw) and a **connectivity rule** (a venue offline ≥5 minutes gets zero
    weight, with the remaining weights renormalised).
  - `Mark Price = Median(Price 1, Price 2, Contract Price)` where
    `Price 1 = Price Index × (1 + Last Funding Rate × Time Until Next Funding / Funding Period)`
    and `Price 2 = Price Index + Moving Average(30-second basis of bid/ask deviation)`.
- **Two things to extract:**
  1. An **index price is a construction, not an observation.** It has constituents, weights,
     outlier caps, staleness rules and failover. CrashLab's M1 oracle (single Binance BTCUSDT
     feed with LIVE/STALE/DISCONNECTED states) is a one-constituent index — the state machine you
     are asked to build is the degenerate case of exactly the machinery on this page. Say that in
     the report.
  2. Binance's mark **does include the contract's own price** — as one of three inputs to a
     median. A median of three is a *robust* aggregator: the local price can be arbitrarily wrong
     and it still cannot move the output beyond the second-worst input. This is the crucial
     distinction: it is not "local price is forbidden", it is "local price must not be able to
     dominate". Your Exchange A doesn't merely *use* the local price, it uses it *alone*.

#### 1C.3 OKX — *Mark price and Last price* — **FREE**, ~20 min

- <https://www.okx.com/en-us/help/ii-mark-price-and-last-price>
  (see also <https://www.okx.com/en-us/learn/mark-price-and-index-price-of-margined-contracts>)
- **Take from it:** the simplest index-plus-basis construction in this list —
  `Mark price = Index price + moving average of (Mid price − Index price)`, with
  `Mid price = (Best ask + Best bid)/2`; index built from "at least three major exchanges" with a
  deviation guard. Stated purpose: "a tool to reduce unnecessary forced liquidation in an
  abnormal volatile market."
- **Why it's on the list:** this is *literally CrashLab's Exchange B minus the clamp*. Reading
  it lets you frame your own design honestly in the report: "Exchange B is OKX's mark price with
  an explicit basis clamp, which is BitMEX's Last-Price-Protected band expressed as a bound on
  the basis rather than on the price."

#### 1C.4 Hyperliquid — *Robust price indices* — **FREE**, ~30 min ★

- <https://hyperliquid.gitbook.io/hyperliquid-docs/trading/robust-price-indices>
- **Take from it, verbatim.** Two *separate* prices with two *separate* jobs:
  - **Oracle price** — "a weighted median of CEX prices … robust because it does not depend on
    Hyperliquid's market data at all". Used for **funding only**. Updated ~every 3 seconds.
  - **Mark price** — used for margin, liquidation, TP/SL and unrealised PnL — is the **median of**:
    1. oracle price + a **150-second EMA of (Hyperliquid mid − oracle)**;
    2. the median of (best bid, best ask, last trade) on Hyperliquid;
    3. the median of Binance / OKX / Bybit / Gate.io / MEXC **perp** mids, weights 3, 2, 2, 1, 1;
    plus, if exactly two of the three exist, a 30-second EMA of input 2.
  - The EMA is time-weighted with an explicit decay:
    `numerator → numerator*exp(-t/2.5min) + sample*t`, `denominator → denominator*exp(-t/2.5min) + t`,
    `ema = numerator/denominator`.
- **Why this is the best single mark-price design to study for CrashLab:**
  - Input 1 **is Exchange B's formula** (`reference + EMA(local_mid − reference)`), to the
    parameter. Hyperliquid publishes the time constant: 150 s.
  - Where CrashLab uses `clamp(·, ±max_basis)` to bound that term, Hyperliquid takes a **median
    with two independent estimates**. Both are robust aggregators; the median is
    parameter-free but needs ≥3 sources, the clamp needs only one but forces you to pick
    `max_basis`. That trade-off is a genuine soutenance answer.
  - The EMA update rule is written in a form that is correct for **irregular sample intervals**,
    which is exactly your situation in an event-driven engine where mid updates arrive on trades
    and book changes, not on a clock. Copy this, don't invent your own.

#### 1C.5 dYdX v4 — margining, again, but read for the *absence* — **FREE**, ~10 min

- Re-read <https://docs.dydx.xyz/concepts/trading/margin>: `Total Account Value = Q + Σ(Sᵢ × Pᵢ)`
  where **P is the oracle price**, full stop.
- **Take from it:** dYdX has **no mark price at all**. Margin and liquidation are evaluated
  against the oracle price with *zero* contribution from its own order book. It is the extreme
  end of the spectrum whose opposite end is CrashLab's Exchange A. Between them sit BitMEX
  (index + funding basis), OKX (index + MA basis), Exchange B (index + clamped EMA basis),
  Hyperliquid (median including local) and Binance (median including last).
  **Draw that spectrum in the M7 report. It is the report's thesis in one line.**

---

### 1D. Bankruptcy, insurance funds, ADL and socialised loss (~3h)

CrashLab requires "les pertes résiduelles alimentent un mécanisme d'assurance simulé et tracé"
and explicitly does *not* require ADL. Read this block anyway — you need it to explain what your
insurance fund is a simplification *of*.

#### 1D.1 BitMEX — *Liquidation* — **FREE**, ~30 min ★

- <https://www.bitmex.com/app/liquidation>
- Sections: *Minimisation of Liquidations* → *Liquidation Process* → *Users on the Lowest Risk
  Limit tiers* → *Users on Higher Risk Limit tiers* → *System Gains and Losses*.
- **Take from it — the canonical liquidation escalation ladder:**
  1. Cancel the account's open orders in that contract, to free margin.
  2. Attempt to step the account down a risk-limit tier (reducing its own margin requirement).
  3. Submit a **FillOrKill** order for just the excess size — *partial liquidation*.
  4. If still under water, the liquidation engine **takes over the whole position** and places a
     limit order at the **bankruptcy price**.
  - **System Gains and Losses**, verbatim in substance: if the position closes *better* than the
    bankruptcy price, the surplus goes to the **Insurance Fund**; if it closes *worse*, the
    Insurance Fund is spent aggressing the position; if that still fails → **Auto-Deleveraging**.
- **The concept to nail down here is the *bankruptcy price*:** the price at which the account's
  equity is exactly zero. Maintenance margin is the buffer *between* the liquidation trigger and
  the bankruptcy price; it exists solely to give the engine room to sell before the account goes
  negative. CrashLab's trigger `equity <= maintenance_margin + estimated_liquidation_fee` is that
  buffer plus the fee. Slippage larger than the buffer ⇒ negative account ⇒ your insurance fund
  pays. Wire this sentence into your M4 report.

#### 1D.2 BitMEX — *Risk Limits* — **FREE**, ~20 min

- <https://www.bitmex.com/app/riskLimits>
- **Take from it:** `New Maintenance Margin % = Base MM% + (Steps × Base MM%)`,
  `New Initial Margin % = Base IM% + (Steps × Base MM%)`, and the stated rationale:
  large positions "pose a risk to others on the exchange who may experience a deleveraging
  event if the position cannot be fully liquidated."
- **Why:** it makes explicit that margin requirements are not a per-account risk control, they
  are a **liquidity control** — the exchange is charging you for the depth your liquidation will
  consume. That reframing is what connects M4 (margin) to M8 (slippage) and M7 (cascade).

#### 1D.3 BitMEX — *Auto-Deleveraging* — **FREE**, ~20 min

- <https://www.bitmex.com/app/autoDeleveraging>
- **Take from it:** when a liquidation cannot be filled by the time the mark price reaches the
  bankruptcy price, opposing positions are force-closed at the bankruptcy price of the liquidated
  order, ranked by
  `Ranking = PNL% × Effective Leverage` (if PNL% > 0), `= PNL% / Effective Leverage` (otherwise).
- **The idea to take:** ADL is how an exchange **guarantees it never has a hole in its balance
  sheet** — by transferring the shortfall to the profitable, high-leverage traders on the other
  side. It converts a solvency problem into a fairness problem. CrashLab's simulated insurance
  fund is allowed to go negative in your ledger; a real exchange's cannot, and ADL is why.

#### 1D.4 Binance — *Futures Insurance Funds* and *What Is Auto-Deleveraging (ADL)* — **FREE**, ~30 min

- <https://www.binance.com/en/support/faq/introduction-to-futures-insurance-funds-360033525371>
- <https://www.binance.com/en/support/faq/what-is-auto-deleveraging-adl-and-how-does-it-work-360033525471>
- **Take from it:** the same insurance-fund arithmetic as BitMEX (surplus in, deficit out), the
  same profit-and-leverage ADL ranking, the ADL indicator shown to users, and one operational
  fact worth noting: coin-margined contracts share one fund per collateral asset, so their funds
  are smaller and ADL is likelier there. That is a *pooling* design decision — how many insurance
  funds do you have and what do they pool across? — and CrashLab (one fund per exchange) is making
  the same decision implicitly.

#### 1D.5 Binance — *Futures Liquidation Protocols* — **FREE**, ~30 min

- <https://www.binance.com/en/support/faq/binance-futures-liquidation-protocols-360033525271>
- **Take from it:** the trigger stated as
  `Collateral = Initial Collateral + Realized PnL + Unrealized PnL < Maintenance Margin`
  and equivalently `Margin Ratio = Maintenance Margin / Margin Balance → 100%`; the
  **liquidation clearance fee** charged on liquidated notional (this is CrashLab's
  `estimated_liquidation_fee` — note it is charged on notional, so it must be *estimated* before
  you know the fill price, which is why the trigger uses an estimate); and the three-stage
  process (single large IOC "smart liquidation" → partial stop if MM restored → full liquidation
  → insurance fund → ADL).

#### 1D.6 Deribit — *The Insurance Fund and Socialised Loss System* — **FREE**, ~20 min ★

- <https://insights.deribit.com/education/the-deribit-insurance-fund-and-socialised-loss-system/>
  (support KB counterpart: `support.deribit.com/hc/en-us/articles/25944777576477-Insurance-Fund`,
  which blocks scripted fetches but opens in a browser)
- **Take from it:** Deribit's fallback after the insurance fund is **not** ADL. It is
  **socialised loss** — the residual deficit is redistributed *pro rata* across the traders who
  were **profitable in that session**. Nobody's position is force-closed; instead everyone's
  profit is haircut.
- **Why this is the most valuable item in §1D:** it proves that "insurance fund → ADL" is not a
  law of nature. There are (at least) three answers to "who eats the bad debt": the winners'
  *positions* (ADL), the winners' *profits* (socialised loss), or the exchange's *own capital*
  (see the Oct-2025 Binance case in Phase 2). CrashLab picks a fourth: a fund that is simply
  tracked and allowed to be drawn down. Knowing all four is a soutenance answer.

---

## 3. Phase 2 — read to understand M7 (the cascade)

M4 teaches you the mechanism. M7 needs you to understand the *feedback loop*, and for that,
post-mortems of real events beat theory. Read them in this order.

### 2.1 CFTC & SEC, *Findings Regarding the Market Events of May 6, 2010* — **FREE**, ~2h ★★

- Staffs of the CFTC and the SEC, report to the Joint Advisory Committee on Emerging Regulatory
  Issues, 30 September 2010.
  Landing page: <https://www.cftc.gov/MarketReports/StaffReportonMay6MarketEvents/staffreport050610marketevents.html>
  PDF: <https://www.sec.gov/news/studies/2010/marketevents-report.pdf>
  (both are regulator-hosted and browser-reachable; `sec.gov` returns 403 to scripts)
- **Read:** the executive summary, then the section on the E-Mini S&P 500 futures market, then
  the sections on liquidity withdrawal and on stub quotes.
- **Why an equities/futures report is first in a crypto list:** it is the most carefully
  investigated cascade in financial history, written by the two regulators with subpoena power
  over the tape, and it isolates each link of the loop that CrashLab's M7 must reproduce:
  1. a large directional order executed against a **volume-participation** rule rather than a
     price limit — i.e. a seller that does not care what price it gets (exactly your
     ScenarioController's synthetic aggressive flow, and exactly a liquidation order);
  2. **"hot-potato" volume** — the same inventory passed rapidly between intermediaries,
     inflating measured volume without adding real liquidity, which then *accelerated* the
     participation-rate algorithm;
  3. market makers **withdrawing** on internal risk limits (your M6 market maker's kill switch
     and stale-oracle withdrawal, and your subject's *"le carnet de A devient temporairement peu
     profond"*);
  4. trades printing at absurd prices against stub quotes because the book was empty.
- **Take from it, above all:** the cascade was *not* caused by a bug. Every system behaved as
  specified. The failure was in the *interaction* of correct components under stress. That is
  CrashLab's thesis restated by a regulator, and it is the single best framing for your
  M7 report's opening paragraph.

### 2.2 Brunnermeier & Pedersen, *Market Liquidity and Funding Liquidity* — **FREE**, ~3h

- Markus K. Brunnermeier and Lasse Heje Pedersen, *Review of Financial Studies* 22(6), 2009,
  2201–2238. Free author PDF: <https://www.princeton.edu/~markus/research/papers/liquidity.pdf>
  (also NBER WP 12939, <https://www.nber.org/papers/w12939>).
- **Read:** the introduction, and the sections that develop the **margin spiral** and the
  **loss spiral**. You can skip the formal proofs; you need the mechanism, not the fixed point.
- **Take from it — the theory of your M7 in two named loops:**
  - **Loss spiral:** prices fall → leveraged traders' equity falls → they must reduce positions →
    selling pushes prices down further.
  - **Margin spiral:** prices fall and volatility rises → *margin requirements themselves rise* →
    the same position now needs more capital → further forced selling.
  - The paper's central result — that **margins are destabilising** when they are set from
    recent price behaviour — is precisely the indictment of Exchange A. Marking at last traded
    price makes margin requirements a function of the local price, so a local price move
    mechanically manufactures margin calls. Exchange B breaks the loop by making the margin
    input largely *exogenous* to the local book.
- This paper is where the words "cascade", "spiral", "fire sale" acquire technical meaning. Cite
  it in the report; it is the standard reference.

### 2.3 BitMEX, *How We Are Responding to the 13 March DDoS Attacks* — **FREE**, ~30 min ★

- <https://www.bitmex.com/blog/how-we-are-responding-to-last-weeks-ddos-attacks>
  (companion same-day note: <https://www.bitmex.com/blog/site-announcement/ddos-attack-13-march-2020>)
- **Context:** 12–13 March 2020 ("Black Thursday"), BTC roughly halved. BitMEX — then the
  dominant BTC perpetual venue — went down twice for ~25 and ~37 minutes at the depth of the
  crash, and the market bounced hard while it was offline.
- **Take from it — three distinct lessons, all first-party:**
  1. **The failure was not in the matching engine.** BitMEX states the trading engine kept
     running and market data was undisrupted; what failed was an *authentication/access layer* in
     front of it, starved by an unindexed query on the chat endpoint. Traders could not reach a
     working engine. This is the cleanest real-world illustration of "correct engine, systemic
     outcome", and it is a direct argument for CrashLab's M0/M2 critical-path rules (no disk, no
     network, no global mutex in matching handlers).
  2. **Last-price-triggered orders misfired.** BitMEX identified 156 accounts whose **Last Price
     stops** on ETHUSD were "clearly erroneously triggered" by late-processed market orders, and
     refunded them by computing the delta to the *printed Index Price*. The exchange's own remedy
     was to fall back to the index — a first-party admission of the last-price-vs-index gap that
     is the whole of soutenance Q2.
  3. **Venue outage as a circuit breaker.** Whether BitMEX going dark stopped the cascade is
     genuinely disputed and BitMEX does not claim it; but the episode is why "what stops a
     cascade?" is a live design question. Your M7 answer — that Exchange B never enters the loop
     because its mark barely moved — is the *designed* version of what happened to BitMEX by
     accident.
- *Honesty flag:* this post is BitMEX defending itself against manipulation allegations. Read it
  as a primary source about *what BitMEX says happened*, and note the incentive.

### 2.4 The 10–11 October 2025 cascade — Binance's USDe/BNSOL/WBETH collateral event — **FREE**, ~1.5h ★★★

This is the closest thing to CrashLab's exact thesis ever to happen at production scale, and it
is very recent, so sourcing needs care. Read all four items and note their differing standing.

1. **Binance (first-party) — compensation announcement**,
   <https://www.binance.com/en/square/post/10-12-2025-binance-to-compensate-users-affected-by-usde-bnsol-and-wbeth-depeg-30878046233481>
   Binance states: the depeg window was **2025-10-10 21:36–22:16 UTC**; all affected Futures,
   Margin and Loan users would be compensated within 72 hours; compensation computed as the
   difference between the market price at 2025-10-11 00:00 UTC and each user's **liquidation
   price**; and — the part that matters most — the forward fix: **redemption prices added into
   the price index weights** for these tokens, a **minimum price threshold** added to the USDe
   index rule, and more frequent risk-parameter reviews.
2. **Binance (first-party) — the $400M support programme**,
   <https://www.binance.com/en/square/post/31014957582105> and
   <https://www.binance.com/en/square/post/10-14-2025-binance-launches-400-million-support-initiative-amid-crypto-market-volatility-31008731846026>
   ($300M to users force-liquidated in the window, $100M institutional facility; framed as
   confidence-restoring, explicitly *not* an admission of liability). Reported total paid on the
   collateral track: ~$283M.
3. **Ethena (counterparty view).** Founder Guy Young's public statement that the discrepancy
   "was isolated to a single venue, which referenced the oracle index **on its own orderbook**,
   not the deepest pool of liquidity", that mint/redeem never stopped, and that USDe remained
   overcollateralised throughout.
   *Sourcing caveat:* the statement was made on X; I could not fetch X directly. It is quoted in
   CoinDesk, "No, Ethena's USDe didn't de-peg" (13 Oct 2025),
   <https://www.coindesk.com/markets/2025/10/13/no-ethena-s-usde-didn-t-de-peg>. **Verify the
   original post before quoting it in your report.**
4. **Academic event study.** See §2.6 below (arXiv:2607.27070), which includes 10 Oct 2025 among
   its seven cascades.

- **What to take, and why it is worth a whole section of your M7 report:**
  - Binance valued *collateral* (USDe, WBETH, BNSOL) using a price index built from **its own
    spot order books**. Under stress those books thinned; the local price of the collateral
    collapsed (USDe printed ~$0.65, BNSOL ~$300→$35, WBETH to ~$430) while the same assets traded
    at par elsewhere and remained redeemable at par at the issuer.
  - Margin systems revalued collateral at the local price → equity collapsed → forced
    liquidations → more selling into the same thin books → further local price collapse.
    **That is the Exchange A loop, run for real, with a ~$283M invoice.**
  - It happened on the **collateral** leg rather than the mark-price leg. Generalise the lesson:
    *any* input to the margin computation that is sourced from the venue's own book creates the
    loop. Mark price is the obvious one; collateral valuation is the one everyone forgot.
  - Binance's own remedy — bringing an **external, non-market price** (the redemption price) into
    the index, plus a floor — is Exchange B's design applied after the fact. Quote it.
- *Discipline note:* keep first-party claims (Binance's announcements, Ethena's statement) and
  third-party interpretation strictly separated in your report. The causal claim "Binance's index
  used only its own book" is Ethena's characterisation plus the strong implication of Binance's
  own fix; Binance has not published its pre-incident index methodology for these assets.

### 2.5 Oracle/mark-price manipulation as a *deliberate* attack (~1.5h)

Read at least the first of these. They convert "mark price design is important" into
"mark price design is an attack surface with a dollar value".

- **CFTC v. Avraham Eisenberg (Mango Markets)** — **FREE**, ~45 min ★
  Complaint PDF: <https://www.cftc.gov/media/8046/enfeisenbergcomplaint010923/download>
  Press release: <https://www.cftc.gov/PressRoom/PressReleases/8647-23> (9 Jan 2023)
  Parallel SEC action: <https://www.sec.gov/enforcement-litigation/litigation-releases/lr-25623>
  **Take from it:** a sworn, itemised description of an oracle-manipulation attack. The
  defendant opened a very large long in MNGO-PERP, then bought the thin MNGO spot market to drag
  the oracle from ~$0.03 to ~$0.91, which made his perp position show enormous *unrealised*
  profit, which the protocol counted as *collateral*, against which he borrowed out the treasury
  (~$110M+). The mechanism is: **unrealised PnL is computed from a manipulable price, and
  unrealised PnL is spendable.** In CrashLab terms, Exchange A's `unrealized_pnl = position_btc
  * (mark_price − avg_entry_price)` with `mark_price = local_last_traded` is the same
  vulnerability, pointed at liquidations instead of at borrowing. A legal document is an
  unusually good source: it is specific, dated, adversarially checked, and free.
  *Note for accuracy — do not overstate the legal outcome.* Eisenberg was convicted by a jury in
  April 2024 on commodities fraud, commodities manipulation and wire fraud; on 23 May 2025 the
  trial judge (Arun Subramanian, S.D.N.Y.) granted a Rule 29 motion and **vacated all three
  convictions**, on insufficiency of the fraud evidence ("Mango Markets was permissionless and
  automatic") and on improper venue. Prosecutors have appealed that acquittal, and the CFTC's
  civil action is separate. **The *mechanics* described in the CFTC complaint are not in dispute;
  the legal characterisation is.** Cite the complaint for how the attack worked, not for a
  verdict.

- **Hyperliquid, JELLY, 26 March 2025** — **FREE**, ~30 min, *weaker sourcing*
  Community write-up: <https://hyperliquid-co.gitbook.io/community-docs/introduction/roadmap/2025-26-03_incident>
  **Take from it:** a self-inflicted mark-price squeeze — a trader opened a large short in a
  thinly-traded perp, then bought the thin spot market to push the mark against a position that
  the protocol's own backstop vault (HLP) had been forced to absorb, turning the vault into the
  bagholder. Validators voted to delist and settle all positions at a chosen price within
  minutes. Two lessons: (a) a *backstop of last resort that takes positions at mark* inherits the
  mark-price vulnerability; (b) the only available remedy was to override the market, which is a
  governance action, not a risk-engine action.
  *Honesty flag:* I could not locate a first-party Hyperliquid Labs post-mortem document — the
  primary record is Hyperliquid's posts on X and the community wiki above. Treat details as
  provisional and verify before citing specifics.

- **dYdX v3, YFI, 17 November 2023** — **FREE**, ~20 min, *weakest sourcing — flagged*
  ~$9M of the v3 insurance fund was consumed covering gaps in liquidating a large crowded long
  in a thinly-traded market; dYdX's founder publicly described it as a targeted attack.
  *Honesty flag:* **I could not find an official dYdX post-mortem document.** The first-party
  record is dYdX's and Antonio Juliano's posts on X, reported secondhand by The Block
  (<https://www.theblock.co/post/263632/dydxs-insurance-fund-lost-9-million-as-a-result-of-targeted-attack>)
  and others. Use it as an *illustration* that insurance funds get drained by crowded positions
  in thin markets, not as a citable technical account.

### 2.6 Empirical/quantitative work on cascades — **FREE**, ~2–3h

- **Ramon Marc Garcia Seuma, "Where does the criticality live? Early-warning signals are
  event-heterogeneous across seven crypto-perpetual liquidation cascades"**, arXiv:2607.27070
  (submitted 29 July 2026; q-fin.ST, physics.soc-ph),
  <https://arxiv.org/abs/2607.27070>
  Seven BTC perpetual cascades 2022–2025 including the 10 Oct 2025 event, at 1-minute and
  5-minute resolution. **Take from it:** the introduction's statement of the loop (leverage →
  adverse move crosses maintenance margin → engine emits forced sells → market impact pushes
  price further → more thresholds crossed) is the cleanest formal write-up of your M7 diagram;
  and the finding that endogenous build-up cascades show critical-slowing-down precursors while
  exogenous news shocks do not, which maps directly onto your "crowded long" vs "news event"
  scenarios in §6 of the subject.
  *Caveat:* very recent preprint, single author, not peer-reviewed as of this writing. Use for
  framing and for its list of events, not as settled fact.

- **Perez, Werner, Xu & Livshits, "Liquidations: DeFi on a Knife-edge"**, Financial Cryptography
  and Data Security 2021, 457–476; arXiv:2009.13235, <https://arxiv.org/abs/2009.13235>
  **Take from it:** the sensitivity result — a **3% move in an asset's price makes >$10M of
  positions liquidatable** in the systems studied. That is the quantitative shape of a
  *liquidation heatmap*, and it justifies the subject's Annex-A heatmap
  (`liquidation_heatmap[price_band] = Σ notional that would liquidate if mark reaches band`).
  Also: >70% of undercollateralised positions were liquidated essentially immediately, i.e.
  liquidator competition is fast — relevant to your liquidation-arbitrage agent's assumptions.

- **Qin, Zhou, Gamito, Jovanovic & Gervais, "An Empirical Study of DeFi Liquidations:
  Incentives, Risks, and Instabilities"**, ACM IMC 2021, 336–350; arXiv:2106.06389,
  <https://arxiv.org/abs/2106.06389>
  **Take from it:** empirical distribution of liquidation *profits*, the observation that
  fixed-discount liquidation incentives systematically overpay liquidators (a wealth transfer
  from the liquidated), and evidence of liquidators front-running each other. Directly informs
  your `LiquidationArbitrageAgent`'s `expected_profit` decomposition in M7.

- **(Optional, ~1h) Ramshreyas Rao, "Agent-Based Simulation of a Perpetual Futures Market"**,
  arXiv:2501.09404, <https://arxiv.org/abs/2501.09404>
  Single-author preprint, q-fin.TR, Jan 2025. **Take from it:** a worked precedent for exactly
  CrashLab's construction — heterogeneous agents on a CLOB trading a perp against a spot
  reference — including which parameters (order lifetime, trading horizon, spread) turned out to
  control whether the perp *pegs* to spot. If your M5 population produces a perp that drifts
  away from the oracle and never comes back, this paper is the first place to look for why.
  Not peer-reviewed; use as a design reference, not as authority.

---

## 4. Where exchanges genuinely disagree

**This is the richest material in the project.** Each row below is a place where competent,
well-capitalised production systems reached *different* conclusions from the same constraints.
Each one is a legitimate soutenance answer of the form *"we chose X; Binance chose Y; the
trade-off is Z"*, and each is a candidate M7 experiment (run the same crash against two mark
price rules and measure).

### 5.1 Mark price — how much may the local book contribute?

Ordered from *no local input* to *only local input*:

| Venue | Mark price for margin/liquidation | Local book weight |
|---|---|---|
| **dYdX v4** | **Oracle price**, directly. No mark price object exists. | 0% |
| **BitMEX** (perps) | `Index × (1 + Funding Basis)`, `Funding Basis = FundingRate × (TimeUntilFunding / FundingInterval)` | 0% — the local book enters only via the funding rate, one interval later |
| **BitMEX** (dated futures) | `Index + Index × %FairBasis × (T/365)`, `%FairBasis` from **Impact Mid**, refreshed only when `ImpactAsk − ImpactBid < 1 maintenance margin` | depth-weighted, with a width gate |
| **OKX** | `Index + MovingAverage(Mid − Index)` | smoothed, unbounded |
| **CrashLab Exchange B** | `Reference + clamp(EMA(LocalMid − Reference), ±max_basis)` | smoothed **and bounded** |
| **BitMEX** *LastPriceProtected* mode | `Last`, confined to a band of 1 maintenance margin around Fair Price; the band is sticky (mark may move toward the band, never away) | last price, hard-bounded |
| **Hyperliquid** | `median{ oracle + EMA₁₅₀ₛ(mid − oracle), median(bid, ask, last), median(5 external perp mids, weights 3/2/2/1/1) }` | present but out-voted by two independent estimates |
| **Binance** | `median(Index × (1 + fundingBasis), Index + MA₃₀ₛ(basis), ContractPrice)` | present but out-voted |
| **CrashLab Exchange A** | `LastTradedPrice` | **100%** |

**The three distinct robustness techniques on display** — learn to name them:
1. **Exclusion** (dYdX, BitMEX perps): the local price simply is not an input.
2. **Bounding** (Exchange B's clamp, BitMEX's Last-Price-Protected band): the local price is an
   input but its influence is capped by construction.
3. **Out-voting** (Binance, Hyperliquid): the local price is one input to a median of ≥3
   independent estimates, so it cannot be the deciding vote.

Then note the **fourth, orthogonal** technique that BitMEX applies on top: a **quality gate** —
stop refreshing the basis when the book is too wide to be informative. That is arguably the
cheapest and most valuable line of code in this whole list for CrashLab, because it is *exactly*
the condition ("le carnet de A devient temporairement peu profond") that the M7 scenario creates.

**Also disagreed: one price or two?** Hyperliquid keeps **oracle price** (for funding) and
**mark price** (for margin) as separate objects with different constructions, because they have
different failure modes: funding must be manipulation-resistant over hours, margin must be
responsive over seconds. Binance/BitMEX/OKX use one index for both. CrashLab implicitly uses two
(reference for funding-premium, mark for margin) — you should say that this is a choice.

### 5.2 Funding rate — four different formulas

| | Rate composition | Damper | Premium source | Interval | Cap |
|---|---|---|---|---|---|
| **BitMEX** | `P + clamp(I − P, ±0.05%)` | ±0.05% clamp *around the interest rate* | Impact bid/ask, 8h TWAP of 1-min samples | 8h, discrete (04/12/20 UTC) | 75%·(IM−MM); change capped at 75%·MM |
| **Binance** | `[avg P + clamp(I − P, ±0.05%)] / (8/N)` | same | Impact bid/ask | 8h default (00/08/16 UTC); **switches to hourly under stress** | per-contract caps/floors |
| **Deribit** | premium only, no interest term | **dead-band** ±0.025% (inside it, rate = 0) | `(Mark − Index)/Index` | **continuous accrual**, transferred every few seconds | per-product cap |
| **dYdX v4** | `(Premium/8) + InterestRate` (0% cross, 0.125bp/h isolated) | none | Impact bid/ask, 60×1-min TWAP | **hourly** | `600% × (IM − MM)` |
| **CrashLab** | `clamp(k · premium, ±max_funding)` | none | local **mid** | configurable | `max_funding` |

**Four separate design questions hiding in that table** — each one is a good report paragraph:
- **Is there an interest-rate term?** It exists because a perpetual is economically a
  margin-financed spot position, so the natural resting funding rate is the interest
  differential between base and quote, not zero. CrashLab drops it (rate = 0 at premium = 0),
  which is defensible in a simulation with no borrowing costs — but say so.
- **Damper vs dead-band.** BitMEX/Binance clamp `(I − P)` so that small premia produce
  `F = I` (funding pulls toward the interest rate). Deribit zeroes the rate inside a band
  (funding does nothing until the premium is real). These are different theories of what the
  resting state should be.
- **Discrete vs continuous.** Discrete funding timestamps create a scheduled, gameable event
  ("you only pay if you hold a position at the timestamp"). Continuous accrual removes it and
  removes an entire class of agent strategy. CrashLab's `funding_period` is configurable —
  make the two regimes a scenario and measure whether your agents learn to dodge the snapshot.
- **Mid vs impact price.** See §1A.3. The mid is manipulable with one lot; the impact price is
  not. This is your cheapest robustness upgrade to M4.

### 5.3 Liquidation execution — five different answers

| Venue | How the position is closed |
|---|---|
| **BitMEX** | Cancel open orders → attempt risk-limit step-down → **FillOrKill** for the excess only → if still failing, engine takes over the whole position and quotes a limit at the **bankruptcy price** |
| **Binance** | Single large **IOC** "smart liquidation" order; if the partial fill restores maintenance margin, stop; otherwise full liquidation; **liquidation clearance fee** on notional |
| **OKX** | **Tiered, three-phase** partial liquidation, each phase handing size to the liquidation engine at the **mark price** and charging maintenance margin per tier |
| **Hyperliquid** | Market order to the book; for positions > 100k USDC only **20% of the position** per attempt with a **30-second cooldown**; below **⅔ of maintenance margin**, the **liquidator vault (HLP)** takes the position at mark |
| **dYdX v4** | Protocol-generated liquidation order with a computed **Fillable Price** (a spread off the oracle that **widens as the account approaches bankruptcy**), plus **per-block caps** on the fraction of a position and the quote quantums per subaccount that may be liquidated |

**What to extract:**
- **Everyone does partial liquidation, and no two do it the same way.** CrashLab requires
  "liquidation partielle d'abord" without specifying how; pick one of these five and cite it.
- **Rate limiting is a first-class risk control.** Hyperliquid's 20%-and-cooldown and dYdX's
  per-block caps are explicit anti-cascade devices: they deliberately *slow the engine down*
  so that liquidation supply does not arrive faster than the book can absorb it. This is the
  single most underrated idea in the list and it is trivially implementable in your
  `LiquidationActor`. **Run the M7 scenario with and without it** — that is a real experiment
  and a strong soutenance moment.
- **Limit-at-bankruptcy-price (BitMEX) vs market order (Hyperliquid) vs oracle-anchored fillable
  price (dYdX).** A market order guarantees closure and unbounded slippage. A limit at the
  bankruptcy price bounds the loss but may not fill. dYdX's widening spread interpolates between
  the two and prices the urgency. CrashLab says liquidation orders "passent par le matching
  engine comme les autres ordres" — which order *type* you choose determines whether the account
  can go negative, and therefore whether your insurance fund is ever touched.

### 5.4 Margin schedule — flat, tiered, or open-interest-dependent?

- **Flat rate** — CrashLab as specified (`maintenance_margin = notional * mmr`).
- **Tiered by position notional** — Binance (`MM = notional × MMR − MaintenanceAmount`, with the
  `MaintenanceAmount` term existing solely to keep the piecewise function continuous), OKX,
  BitMEX risk limits (`New MM% = Base MM% + Steps × Base MM%`).
- **Scaled by market-wide open interest** — dYdX v4: IMF (not MMF) rises linearly between an
  `open_notional_lower_cap` and `open_notional_upper_cap`.

**Take:** tiering by position size is a *liquidity* control (it charges you for the depth your
liquidation will eat); scaling by open interest is a *systemic* control (it charges everyone for
crowding). CrashLab's flat rate removes both stabilisers, which is *why* the M7 cascade works —
worth stating explicitly rather than leaving as an accident of the spec.

### 5.5 Who eats the bad debt? — four incompatible answers

| Mechanism | Venue | Who pays |
|---|---|---|
| **ADL ranked by profit × leverage** | BitMEX (`PNL% × EffectiveLeverage` if PNL%>0, else `PNL%/EffectiveLeverage`), Binance, OKX (executed at mark price; OKX also triggers when the fund falls 30% from peak within 8h, not only at zero) | winning traders' **positions** are force-closed |
| **Socialised loss** | Deribit | winning traders' **profits** are haircut pro rata; positions untouched |
| **Deleveraging against a *randomly chosen* offsetting position** | dYdX v4 | a randomly selected opposing account |
| **Exchange capital / discretionary compensation** | Binance, Oct 2025 (~$283M + a $400M programme) | the **exchange** |
| **Backstop vault absorbs the position** | Hyperliquid (HLP liquidator vault) | the vault's depositors — i.e. anyone who provided capital to it |

**dYdX's random selection vs everyone else's profit×leverage ranking is the sharpest single
disagreement in this document.** Ranking by profit and leverage is *incentive-aligned* (it
punishes the traders whose winning leveraged bets created the imbalance) but *predictable* — you
can compute your own ADL rank and trade around it, and it concentrates the pain on exactly the
traders who were right. Random selection is *unpredictable* (nothing to game) but arbitrary. Ask
yourself which you would ship, and be ready to defend it. Neither is obviously correct.

### 5.6 Insurance fund scope

- One fund per **exchange** (CrashLab).
- One fund per **collateral asset**, shared across all contracts using it (Binance coin-margined
  — and Binance itself notes this makes those funds smaller and ADL more likely).
- One fund per **currency pool** (Deribit: separate BTC, ETH and USDC pools).
- One fund per **isolated market**, plus a shared one for cross markets (dYdX v4).

**Take:** the scope of the pool determines what is cross-subsidising what. A single fund makes a
blow-up in one instrument everyone's problem; per-market funds contain it but each fund is
thinner. This is the same pooling-vs-isolation trade-off as cross vs isolated margin, moved up a
level. CrashLab has one instrument per exchange so the question is degenerate — say so, and say
what you would do with two.

---

## 5. Answering the two named questions cold

### 6.1 Soutenance Q2 — "why should local last price and mark price not always be identical?"

Everything you need is in Phase 1. Build the answer in five moves:

1. **What the mark price is *for*.** It is the input to `unrealized_pnl`, `equity` and
   `maintenance_margin`, i.e. to a *forced, irreversible* action taken against a customer without
   their consent. The last traded price is a *historical record* of one transaction. Different
   jobs, different requirements. — *§1C.1 BitMEX Fair Price Marking, §1B.3 dYdX Margining.*
2. **What a single last trade actually proves.** One print of one lot at the top of a thin book
   proves that one counterparty was willing to trade one lot there. It is not an estimate of the
   value of anyone else's position. Impact prices exist precisely because the industry decided
   the top of book is not evidence. — *§1A.3 dYdX, §1C.1 BitMEX impact notional.*
3. **The attack.** If mark = last, then the cost of moving every account's margin is the cost of
   one trade at the top of a thin book. Cite BitMEX's own stated rationale ("unnecessary
   liquidations may occur if the market is being manipulated, is illiquid…"), then cite Mango
   Markets (§2.5) as the same vulnerability actually exploited for >$110M, and the Oct-2025
   Binance collateral event (§2.4) as the same vulnerability triggered without an attacker.
4. **The feedback loop.** Even with no attacker and no manipulation, mark = last closes a loop:
   liquidation orders are market orders; market orders move the last price; the last price is the
   mark; the mark triggers liquidations. The system's output is wired to its own input. That is
   Brunnermeier–Pedersen's margin spiral (§2.2) and the CFTC/SEC flash-crash mechanism (§2.1).
   **Exchange A is not "using a worse number" — it is closing a control loop that should be
   open.** That sentence is the whole project.
5. **What "not identical" does *not* mean.** It does not mean the local price is irrelevant.
   Binance and Hyperliquid both feed local prices into the mark; Exchange B feeds a smoothed
   basis. The design rule is not *exclude* the local price but *deny it the deciding vote* —
   by exclusion, by bounding, or by out-voting (§5.1). Finish by naming which of the three
   Exchange B uses and why (bounding: it's the only one available when you have exactly one
   external reference).

**Bonus point available:** BitMEX's own *Last Price Protected* mode is a supported production
marking method that *is* last-price-based, and it is safe only because of the ±½-maintenance-margin
band. So the honest answer to "must they differ?" is: *they may coincide, provided the mark is
prevented by construction from following the last price beyond a bounded distance from an
external anchor.* Exchange A has no such construction.

### 6.2 Soutenance Q5 — "why is open interest alone insufficient to precisely predict liquidations?"

Open interest is `Σ|positionᵢ| / 2` (subject, Annex A) — a **scalar aggregate of size**. The
liquidation condition, `equity ≤ maintenance_margin + fee`, expands (per §1B.1–1B.3) to a
function of, **per account**:

- `avg_entry_price` — determines unrealised PnL at any mark. Two books with identical OI but
  different entry distributions liquidate at completely different prices.
- `wallet_balance` — an account with 3× the collateral behind the same position is untouchable
  where the other dies. OI cannot see the collateral leg at all.
- **leverage** — hence `initial_margin`, hence the distance from entry to trigger. This is why
  the subject ships a **leverage percentile table** rather than a single leverage number: the
  liquidation price distribution is a function of the *whole distribution*, and it is heavily
  skewed (the given table runs 2× at p5 to ~95× at p95). The top decile of accounts contributes
  most of the liquidation notional in the first price band.
- `maintenance_margin_rate` — flat in CrashLab, but **tiered by notional** at Binance/OKX/BitMEX
  and **OI-scaled** at dYdX (§5.4). Where it is tiered, the same aggregate OI split into a few
  whales versus many minnows produces different thresholds *and* different margin requirements.
- **cross vs isolated, and the rest of the account.** Binance's cross-margin liquidation price
  takes as inputs the maintenance margin of *all other* contracts and the unrealised PnL of *all
  other* positions (§1B.2). A position's liquidation price is not a property of that position.
- **sign / directionality.** OI does not tell you whether the crowd is long or short. The subject
  makes this the *precondition* of the M7 scenario ("une majorité d'agents possède une position
  longue ou courte similaire"), which is exactly the fact OI conceals.
- **time.** Traders add margin, close, or hedge. A predicted liquidation is a prediction about a
  human decision, not only about a price.

Then land two structural points:

- **Even a perfect prediction of *which* accounts liquidate does not predict the *price impact*,**
  which depends on the book's depth *at that moment* and on the liquidation engine's execution
  policy — market vs limit-at-bankruptcy, full vs 20%-with-cooldown, per-block caps (§5.3). Same
  OI, same positions, same trigger, different `LiquidationActor` ⇒ different cascade. That is
  the M7 result you are being asked to demonstrate.
- **The observable data is itself censored.** Binance's public liquidation WebSocket
  (`<symbol>@forceOrder`) pushes at most **one liquidation order per symbol per second — the
  largest one in that window** — and pushes nothing if none occurred. Every public "liquidations"
  figure derived from that feed therefore systematically *undercounts*, and undercounts most
  severely exactly during a cascade when many liquidations occur in the same second.
  Source: Binance, *Liquidation Order Streams*,
  <https://developers.binance.com/docs/derivatives/usds-margined-futures/websocket-market-streams/Liquidation-Order-Streams>
  (and the coin-margined *All Market Liquidation Order Streams* counterpart).
  *Sourcing caveat:* that page is client-rendered and I could not fetch it directly; the wording
  above is from the page as indexed. **Confirm it in a browser before quoting it verbatim.** It
  is worth confirming: it is a striking, checkable fact and it turns Q5 into a point about
  *observability*, not just about arithmetic.

The constructive complement is the subject's own **liquidation heatmap** (Annex A) — which is
exactly the object you get when you replace OI with the *joint distribution* of (size, entry
price, leverage, collateral) and integrate the trigger condition over price. Frame the heatmap in
the report as "the statistic open interest should have been"; cite Perez et al. (§2.6) for the
empirical shape ("a 3% move makes >$10M liquidatable").

---

## 6. Suggested order and budget

| # | Item | Time | Free? |
|---|---|---|---|
| 1 | Hull ch. 2 §2.2–2.4 (+ §2.3 convergence) | 2h | paid |
| 2 | CFTC Glossary (o, m, i, b, v) | 20m | free |
| 3 | BitMEX *Perpetual Contracts Guide* | 1.5h | free |
| 4 | Deribit Insights *Perpetual Swap Funding* | 40m | free |
| 5 | dYdX *Funding* | 30m | free |
| 6 | Binance *Leverage and Margin* + *Liquidation Price* | 1.5h | free |
| 7 | dYdX *Margining* | 45m | free |
| 8 | **BitMEX *Fair Price Marking*** ★★ | 45m | free |
| 9 | Binance *Mark Price and Price Index* | 45m | free |
| 10 | OKX *Mark price and Last price* | 20m | free |
| 11 | Hyperliquid *Robust price indices* | 30m | free |
| 12 | BitMEX *Liquidation* + *Risk Limits* + *Auto-Deleveraging* | 1.5h | free |
| 13 | Binance *Insurance Funds* + *ADL* + *Liquidation Protocols* | 1h | free |
| 14 | Deribit *Insurance Fund and Socialised Loss* | 20m | free |
| 15 | Hull ch. 5 §5.12, §5.14 | 1h | paid |
| 16 | dYdX v4 source (`x/subaccounts`, `x/clob/keeper/liquidations.go`, `deleveraging.go`, `liquidations_config.proto`) | 2h+ | free |
| — | **↑ everything above before writing M4** | **~16–18h** | |
| 17 | He et al., *Fundamentals of Perpetual Futures* | 2h | free |
| 18 | CFTC/SEC *May 6, 2010* report | 2h | free |
| 19 | Brunnermeier & Pedersen | 3h | free |
| 20 | BitMEX 13 March 2020 response | 30m | free |
| 21 | Oct 2025 Binance/Ethena collateral event (4 items) | 1.5h | free |
| 22 | CFTC v. Eisenberg complaint | 45m | free |
| 23 | Garcia Seuma arXiv:2607.27070; Perez et al.; Qin et al. | 3h | free |
| 24 | Hyperliquid JELLY; dYdX YFI (weak sourcing) | 45m | free |
| — | **↑ everything above before M7** | **~14h** | |

Only two items in the entire list are paid, and both are the same book.

---

## 7. Source-quality notes and things I could not verify

Stated plainly, as the ticket requires.

- **BitMEX `bitmex.com/app/*` pages are client-rendered.** They display normally in a browser but
  return an empty shell to scripts, and the Internet Archive's recent captures are also empty.
  I verified their content against **archived 2019 captures** of the same URLs (fairPriceMarking,
  liquidation, autoDeleveraging, riskLimits, perpetualContractsGuide). All five URLs currently
  return HTTP 200. **The formulas and section names I quote are from the 2019 text; current
  parameter values (funding timestamps, risk-limit tables, margin percentages) will have
  changed.** Read the live pages for numbers; the 2019 text is reliable for structure and
  reasoning.
- **`support.bitmex.com`, `support.deribit.com`, `sec.gov` and `cftc.gov` block scripted
  fetches** (Cloudflare / 403). All are browser-reachable. Where I relied on such a page I have
  said so.
- **Binance's Oct-2025 announcements:** I verified the content of the Binance Square posts linked
  in §2.4 by direct fetch. I could **not** locate the underlying
  `binance.com/en/support/announcement/detail/...` permalinks, and Binance's announcement search
  API is not scriptable from here. If you need the canonical announcement IDs, find them from the
  announcements hub in a browser.
- **Binance's pre-incident index methodology for USDe/BNSOL/WBETH is not published.** The claim
  that the index referenced Binance's own order books is (a) Ethena's founder's characterisation
  and (b) strongly implied by Binance's own remedy (adding redemption prices and a floor to the
  index). It is *not* a Binance statement. Do not present it as one.
- **Ethena/Guy Young's statement** is on X; I could not fetch X. I have it only via CoinDesk's
  quotation. Verify the original before quoting.
- **Binance's `forceOrder` one-per-second note** (§6.2) comes from the developers.binance.com
  page as indexed by search; the page is client-rendered and I could not fetch it directly.
  Confirm in a browser.
- **No official dYdX post-mortem exists for the Nov-2023 YFI insurance-fund event** that I could
  find, and **no official Hyperliquid Labs post-mortem for the March-2025 JELLY event**. Both are
  included with that flag. Do not cite technical details from either as established fact.
- **arXiv:2607.27070** is a recent single-author preprint, not peer-reviewed. **arXiv:2501.09404**
  likewise. Both are flagged in place.
- **Hull chapter/section numbers were verified** against the contents of the 11th Global Edition
  (Pearson, 2021): §2.4 *The operation of margin accounts*, p. 51; §2.3 *Convergence of futures
  price to spot price*, p. 50; ch. 5 *Determination of forward and futures prices*, §5.12 p. 143,
  §5.14 p. 144. Earlier editions renumber — check your copy.
- **Not verified, therefore not cited:** Deribit's exact mark-price construction for linear
  perpetuals (the support KB article blocks scripted access and I would not guess it); current
  Binance and Deribit funding-rate caps per contract; CME Group education URLs (timed out).

## 8. Deliberately excluded

- **Coinglass / Kaiko / CryptoQuant liquidation dashboards.** Useful for intuition, but they are
  derived from the censored `forceOrder`-style feeds described in §6.2 and their methodologies
  are not published. Not primary; do not cite figures from them in the report.
- **Exchange blog "explainers" and third-party academies** (other than the two Deribit Insights
  pieces, which are written by Deribit about Deribit's own mechanism and read as spec).
- **Options and volatility** — that is M9, and a separate reading problem.
- **Order-book microstructure, price-time priority, slippage measurement, VaR** — tickets 03 and
  05.
- **CCP default-waterfall and SPAN margin literature.** It is the correct traditional-finance
  analogue of the insurance-fund/ADL waterfall and it is genuinely interesting, but it is a large
  detour and the crypto docs above already give you the mechanism. Revisit only if you want to
  extend the M4 report with a "how does this compare to a regulated clearing house" section —
  in which case start from Hull ch. 2 §2.5 (OTC markets / central counterparties).
