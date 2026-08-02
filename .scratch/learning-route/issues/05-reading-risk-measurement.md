# Reading list: risk measurement

Type: research
Status: resolved
Blocked by: —

## Question

M8 (8 points) demands slippage measurement, historical VaR and cross-exchange
netting; the metrics table in M7 demands drawdown, time-unhedged and inventory
peak. Find the sources that teach measuring risk, for a programmer who has never
done it.

**Concepts that must be covered:**

- **Slippage** — the subject's formula is
  `slippage_bps = side_sign * (fill_vwap - arrival_price) / arrival_price * 10000`.
  Understand what "arrival price" means and why the choice of benchmark is
  contested; how partial fills and maker/taker fees enter; why this is really
  *implementation shortfall* under another name.
- **VWAP** and the family of execution benchmarks.
- **Historical VaR** — how it is computed from a return series, what the 99%
  figure actually claims, and its well-known failures (it says nothing about the
  shape of the tail beyond the cutoff). Expected Shortfall as the standard
  remedy — a listed bonus in the subject.
- **Netting and aggregation** — why `VaR_A + VaR_B` is wrong when the two
  positions hedge each other. Soutenance question 8 asks how VaR was aggregated
  across A and B. Correlation, diversification benefit, and why naive addition
  is a real institutional mistake and not a toy concern.
- **Maximum drawdown** — computed on equity, and why it is a different kind of
  statement from VaR.
- **Delta** as an exposure measure, enough for `net_btc_delta = delta_A +
  delta_B + option_delta` and for delta-hedging in M9.
- **Latency as a distribution, not a number.** Soutenance question 7 asks why a
  mean latency is insufficient. Cover percentiles, p99/p99.9, tail latency, and
  why coordinated omission makes naive benchmark harnesses lie. This is systems
  material rather than finance, but it is measurement discipline and belongs
  here.
- **Pre-trade risk controls** — the subject lists ten (`MAX_ORDER_SIZE`,
  `MAX_POSITION`, `MAX_NOTIONAL`, `MAX_LEVERAGE`, `MAX_DAILY_LOSS`,
  `ORDER_RATE_LIMIT`, `STALE_ORACLE`, `PRICE_BAND`, `INSUFFICIENT_MARGIN`,
  `KILL_SWITCH_ACTIVE`). Find what real trading systems check pre-trade and why
  each control exists — most of them exist because something went wrong once.

**Sources to prefer**: regulatory and exchange risk documentation, the standard
risk-management texts (name chapters), and for the latency material, the
practitioner literature on measuring tail latency correctly. Post-mortems of
risk-control failures are especially valuable — Knight Capital and similar.

## Answer format

An annotated reading list ordered for comprehension, with what to take from
each. Separate what is needed to *implement* M8 from what is needed to *defend*
it at the soutenance.

## Answer

Resolved. Full deliverable: `../research/05-risk-measurement.md` (1345 lines) —
~40 sources across six dependency-ordered tracks: **A** execution cost, **B**
VaR and Expected Shortfall, **C** aggregation and netting, **D** drawdown/delta/
inventory, **E** latency as a distribution, **F** pre-trade controls and the
incidents that created them.

**The best find on the list is BCBS Working Paper 19** (free, bis.org), which
answers soutenance Q8 from a primary regulatory source. Summing
compartmentalised VaR is conservative *only* when the risks are genuinely
distinct; where the separation exists "due only to accounting rules" — precisely
CrashLab's A/B split of one BTC exposure — the sum "may **understate** the risk."
It also notes that 99% VaR is superadditive for tail indices above 6, which it
calls "realistic cases in market risk." This turns the subject's assertion that
naive addition is incorrect into something with a citation behind it.

**RiskMetrics Technical Document (1996)** §3.4.1 supplies a documented case of a
real regulator — the EU Capital Adequacy Directive — summing risk numbers and
overestimating risk, and §3.1's hierarchical VaR limit chart is structurally the
A/B/aggregate shape CrashLab builds.

**The SEC's Knight Capital order (34-70694)** was read in full, and paragraphs
20–27 map almost line by line onto the subject's ten mandated pre-trade controls
— position limits that ignored working orders, a 9.5% price band too wide to
bite, a monitoring tool (PMON) that was a *post-execution dashboard* rather than
a control, and no self-halt. This is the answer to "why ten controls, and why
these ten." The **FIA Guide (March 2015) §1** maps one-to-one onto the same
list, and the deliverable includes a table pairing each FIA control with each
CrashLab check, with verified quotes.

**Basel's 1996 backtesting framework** gives a directly implementable validation
test: green 0–4, yellow 5–9, red 10+ exceptions over 250 days at 99%. This is
worth promoting into the route explicitly, because it converts M8 from
"computed a number" into "validated a model" — a materially better thing to have
built and a much better thing to defend.

**The entire latency track is free** apart from Gregg's book: Tene on
coordinated omission, HdrHistogram (including the C port, whose
`hdr_record_corrected_value` matters for Exchange A), Dean & Barroso on tail
latency, Ousterhout, and Georges et al. on measurement methodology.

Both cold questions — Q7 (why an average latency is insufficient) and Q8 (how to
aggregate VaR across A and B) — are written out in §8 as full answers in four
escalating layers, each with its sources attached.

**Honesty flags:** §9 lists **16 unverified items**, including Almgren & Chriss'
usual free PDF now returning 403; Hull's section numbers within chapters 12/13
(chapter titles confirmed, sections not); the Flash Crash report and CFTC Mango
figures confirmed live and correctly titled but **not read**; and the 97.5% ES
figure sourced only from the FRTB explanatory note rather than the standard's
own paragraph text. No chapter numbers, URLs or incident details were guessed.
