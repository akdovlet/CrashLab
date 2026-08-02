# Reading list: risk measurement (M8, plus the M7 metrics table and the M11 benchmarks)

Ticket: `.scratch/learning-route/issues/05-reading-risk-measurement.md`
Reader assumed: strong programmer, C++98 fluent, **zero** finance background, **zero**
testing/benchmarking background.
Goal: depth of understanding. No deadline.

Every URL below was fetched or HTTP-checked during research on 2026-08-02 unless the entry
says otherwise. Where I could not verify something, it is flagged in the entry and again in
§9 "Things I could not verify".

---

## 0. How this list is shaped

The ticket spans two disciplines that share one idea: **a single number is not a
measurement**. In finance the number is a loss quantile; in systems it is a latency. Both
halves of M8/M11 turn on understanding a *distribution* and on aggregating distributions
correctly.

Six tracks, in dependency order:

| Track | Covers | Subject hooks |
|---|---|---|
| **A** | Execution cost: arrival price, VWAP, implementation shortfall | M8 slippage formula, M7 "Slippage" metric |
| **B** | Loss distributions: historical VaR, Expected Shortfall, backtesting | M8 "VaR historique 99 %" |
| **C** | Aggregation & netting across A and B | M8 "somme naïve vs VaR nette", soutenance Q8 |
| **D** | Drawdown, delta, inventory | M7 metrics table, M8 `net_btc_delta`, M9 delta-hedge |
| **E** | Latency as a distribution | M11 benchmarks, soutenance Q7 |
| **F** | Pre-trade risk controls and the incidents behind them | M8 ten controls |

Tracks A–D are finance. E is systems. F is regulatory/practitioner. **E and F are the
cheapest tracks and give the highest marginal return** — if you only have one weekend,
do E and F first; they are short, free, and both soutenance questions listed in the ticket
(Q7, Q8) are answerable from E and C alone.

Reading time estimates are for a careful first pass by someone new to the vocabulary, not
for skimming.

---

## Track A — Execution cost: what "slippage" actually measures

The subject's formula is

```
execution_slippage_bps = side_sign * (fill_vwap - arrival_price) / arrival_price * 10000
```

This is **implementation shortfall with the arrival price as the decision price**, expressed
in basis points. Everything contested about it lives in the choice of `arrival_price`.

### A1. Harris, *Trading and Exchanges: Market Microstructure for Practitioners* — Chapter 21

- Larry Harris, Oxford University Press, 2003. ISBN 9780195144703.
  Publisher page: https://global.oup.com/academic/product/trading-and-exchanges-9780195144703
- **Chapter 21, "Liquidity and Transaction Cost Measurement."**
- **Paid** (book, ~£50–70). No legitimate free copy.
- **~2–3 hours** for Ch. 21 alone.
- **Take from it:** the taxonomy of transaction costs — commissions/fees (explicit) vs.
  bid-ask spread, market impact, delay cost and opportunity cost (implicit); why implicit
  costs dominate for anything large; why any cost measurement needs a *benchmark price* and
  why every candidate benchmark is gameable. This is the vocabulary layer. If issue 03
  (order books / microstructure) already assigns Harris, this chapter is the natural
  extension of that reading and you do not need to buy a second book.
- **Caveat I must flag:** I verified the chapter title as "Liquidity and Transaction Cost
  Measurement" from secondary sources (search summaries of the book's TOC), not by reading
  the OUP contents page directly — the OUP page returned no usable content to my fetcher.
  Treat the chapter *number* as high-confidence, the exact wording of the title as
  medium-confidence.

### A2. Perold, "The Implementation Shortfall: Paper versus Reality" (1988)

- André F. Perold, *Journal of Portfolio Management*, Vol. 14, No. 3 (Spring 1988), pp. 4–9.
  https://jpm.pm-research.com/content/14/3/4 —
  also https://www.hbs.edu/faculty/Pages/item.aspx?num=2083
- **Paid** (JPM paywall; ~$40 single article). Many university libraries carry it.
- **~1 hour.** It is a short paper.
- **Take from it:** the founding definition — the shortfall is the return difference between
  a *paper portfolio* (executed instantly at the decision price, no costs) and the *real
  portfolio*. Perold's contribution was to insist that **the opportunity cost of not
  trading, or of trading late, is a real cost** and belongs in the measurement. This is why
  your `arrival_price` must be captured at the moment the agent *decides*, not at the moment
  the order reaches the book: if you timestamp the arrival price after your own latency, you
  have silently deleted your own delay cost from the measurement. That single sentence is
  worth the price of the paper.
- This is the paper the subject's formula descends from. Cite it by name at the soutenance.

### A3. Mittal (ITG), "Implementation Shortfall — One Objective, Many Algorithms"

- Hitesh Mittal, ITG. Undated trade publication article (the copy I read cites Perold 1988
  as footnote 1). Free PDF mirror:
  https://www.cis.upenn.edu/~mkearns/finread/impshort.pdf (HTTP 200, verified; it is a
  course-page mirror on Michael Kearns' UPenn reading list, not the publisher's own copy —
  I could not locate the original publisher URL).
- **Free. ~30–45 minutes.**
- **Take from it:** the clearest short statement of *why the benchmark choice is contested*.
  Direct paraphrase of its argument: VWAP endures because it is *easy to attain* — "it is a
  moving target, and hence a more forgiving benchmark than arrival prices." An algorithm
  that simply tracks the volume curve will hit VWAP even if the stock moves hugely during
  the day, because the benchmark moved with it. Arrival-price (shortfall) benchmarking is
  unforgiving: trade fast and you pay market impact; trade slow and volatility moves the
  price away from you. It also names the trade-off you will re-derive in CrashLab:
  impact vs. opportunity cost, mediated by order size, available liquidity and volatility.
- **Why it matters for M8:** it is the source you quote when an examiner asks "why arrival
  price and not VWAP?" Answer: because VWAP measures *how well you tracked the market*,
  while arrival price measures *what your decision actually cost you*, and CrashLab's
  agents are being graded on decisions, not on tracking.

### A4. Berkowitz, Logue & Noser, "The Total Cost of Transactions on the NYSE" (1988)

- Stephen A. Berkowitz, Dennis E. Logue, Eugene A. Noser Jr., *The Journal of Finance*,
  Vol. 43, No. 1 (March 1988), pp. 97–112.
  https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1540-6261.1988.tb02591.x
- **Paid** (Wiley / JSTOR).
- **~1 hour.** Optional — read the abstract and §I if you are short of time.
- **Take from it:** this is the paper that put VWAP on the map as a *cost benchmark*
  (it used the volume-weighted average price over the trading day as the yardstick against
  which ~14,000 real trades were measured; it reported total costs averaging 23bp, split
  ~18bp commission and ~5bp execution). Read it as the counterweight to A2: it is where the
  "other" benchmark family comes from, and knowing both origins is what lets you say at the
  soutenance that the benchmark question is *contested* rather than merely arbitrary.

### A5. Almgren & Chriss, "Optimal Execution of Portfolio Transactions" (2000/2001)

- Robert Almgren & Neil Chriss, *Journal of Risk*, Vol. 3, No. 2, pp. 5–39.
- **Paid** at the journal. **Free author copies circulate** — the widely cited one is
  `https://www.cims.nyu.edu/~almgren/papers/optliq.pdf`, but that host returned HTTP 403 to
  me today so **I cannot confirm it is currently live**; check Almgren's own page or a
  library.
- **~3–4 hours** (it is a real maths paper; §1–§3 suffice).
- **Take from it:** the formalisation of the impact/risk trade-off — a fast execution has
  low variance around the arrival price but high impact cost; a slow one has low impact but
  high variance. There is an efficient frontier of execution strategies. You do **not** need
  this to implement M8. You need it if you want to *justify* your agents' order-slicing
  behaviour, or if M7's `expected_slippage` term in the arbitrage agent's profit equation
  gets questioned.
- **Optional.** Skip on a first pass; come back if you build a slicing algorithm.

### A6. Kissell, *The Science of Algorithmic Trading and Portfolio Management*

- Robert Kissell, Academic Press/Elsevier, 2013. ISBN 9780124016897.
  https://www.sciencedirect.com/book/monograph/9780124016897/the-science-of-algorithmic-trading-and-portfolio-management
- **Chapter 3, "Algorithmic Transaction Cost Analysis"** and **Chapter 4, "Market Impact
  Models."** (TOC verified via the Google Books record for this ISBN.)
- **Paid** (book; often available through institutional ScienceDirect access).
- **~4 hours** for Ch. 3–4.
- **Take from it:** the *engineering* version of implementation shortfall — how to decompose
  a realised shortfall into delay cost, impact cost and opportunity cost when you have
  partial fills, multiple child orders and fees; and how to attribute cost per child order.
  This is the source that turns Perold's definition into something you can actually code
  against a fill log.
- **This is the one book on Track A that directly serves the "partial fills and maker/taker
  fees" clause in the subject.** If you buy one execution book, buy this one rather than
  Harris (Harris gives you the concepts; Kissell gives you the arithmetic).

### A7. Fee mechanics: read one real exchange's fee schedule

- Any live perp venue's fee documentation. It does not matter which; what matters is that
  you see a real maker/taker table with negative maker rebates and tiered taker fees, and a
  real funding-rate page.
- **Free. ~30 minutes.**
- **Take from it:** fees are *signed* and *side-dependent*. A maker rebate makes your
  effective fill price better than your printed fill price. If your slippage number ignores
  fees you are measuring the wrong thing; if it double-counts them (once in `fill_vwap`,
  once as a separate fee term) you are measuring the wrong thing differently. Decide once,
  document the convention in your report, and assert it in a test.
- **Concrete design note for M8:** compute `fill_vwap` as *gross* (quantity-weighted trade
  prices only), keep fees as a separate additive term in bps, and publish both
  `execution_slippage_bps` and `all_in_cost_bps = execution_slippage_bps + fee_bps`. This
  makes the convention visible instead of buried, and it is the answer to "did you include
  fees?" at the soutenance.

---

## Track B — Loss distributions: historical VaR and Expected Shortfall

### B1. BCBS, "Explanatory note on the minimum capital requirements for market risk" (2019)

- Basel Committee on Banking Supervision, January 2019.
  **https://www.bis.org/bcbs/publ/d457_note.pdf** (verified, HTTP 200, free)
- **Free. ~45 minutes** (it is ~15 pages; read the sections "Weaknesses in the internal
  models approach" and "New type of internal model to capture tail risk and market
  illiquidity: expected shortfall", which includes **Graph 1: Expected shortfall compared
  to value-at-risk**).
- **Read this first on Track B.** It is short, free, written for non-specialists, and it is
  a *primary regulatory* source rather than a textbook restatement.
- **Take from it, verbatim:**
  > "While VaR calculates the maximum potential loss at a certain confidence level (eg a
  > 97.5% VaR measures a loss that is expected to be exceeded only 2.5% of the time), ES
  > calculates the average loss above a certain confidence level (eg a 97.5% ES measures the
  > average of the worst 2.5% of losses)."

  and the footnote:
  > "whereas VaR calculates the losses at a single cut-off point in the distribution … ES
  > looks at the average of any loss that exceeds the cut-off point … The difference between
  > ES and VaR outcomes increases in cases of fat-tailed distributions. In the revised market
  > risk framework, the 97.5th percentile ES is roughly equivalent to the 99th percentile
  > VaR used in Basel 2.5."

  and the failure diagnosis that motivated the change:
  > "(a) Incentives for banks to take on tail risk. … the design of the VaR and stressed VaR
  > metrics fundamentally ignored losses that had less than a 1% probability of occurring.
  > This created perverse incentives to hold positions that featured significant tail risks
  > but were subject to limited risk in 'normal' conditions."
- **Why it matters:** the subject lists ES as a bonus. This document is the shortest
  credible answer to "why bother?" — *the world's bank regulator replaced VaR with ES for
  exactly the reason the ticket names.* That is a much stronger soutenance answer than
  "because a textbook said VaR ignores the tail."

### B2. Hull, *Risk Management and Financial Institutions* — Chapters 12 and 13

- John C. Hull, Wiley. 5th ed. 2018, ISBN 9781119448112; 6th ed. also exists.
  https://www.wiley.com/en-ie/Risk+Management+and+Financial+Institutions,+5th+Edition-p-9781119448099
- **Chapter 12, "Value at Risk and Expected Shortfall"** — including the sections on
  Expected Shortfall and on **Coherent Risk Measures**.
  **Chapter 13, "Historical Simulation and Extreme Value Theory."**
- **Paid.** **~5–6 hours** for both chapters worked through with a pencil.
- **Take from it:**
  - Ch. 12: the definition of VaR as a quantile of a loss distribution over a *stated
    horizon* at a *stated confidence*; the square-root-of-time scaling rule and its
    assumptions; the coherence axioms and the worked counter-example showing VaR failing
    subadditivity while ES does not. Hull's counter-example is the one you should be able to
    reproduce on a whiteboard.
  - Ch. 13: **the actual algorithm you will implement.** Historical simulation: take *N*
    historical one-period changes in the risk factors, apply each of them to *today's*
    portfolio, revalue, sort the *N* resulting P&Ls, and read off the quantile. Note the
    critical detail: you re-apply *historical factor moves* to the *current* position — you
    do not use the historical P&L of a historical position.
- **Chapter numbering caveat:** chapter *titles* 12 and 13 are confirmed for the 5th
  edition. Section numbers within them (e.g. "12.5 Coherent Risk Measures") come from a
  4th-edition TOC I saw in search results and I did **not** open the book — verify section
  numbers against your own copy before quoting them.

### B3. RiskMetrics Technical Document, 4th edition (J.P. Morgan / Reuters, Dec 1996)

- **https://www.msci.com/documents/10199/5915b101-4206-4ba0-aee2-3449d5c7e95a**
  (verified: this is the December 1996 4th edition; free, hosted by MSCI which now owns
  RiskMetrics). Landing page:
  https://www.msci.com/research-and-insights/paper/1996-riskmetrics-technical-document
- **Free.** ~380 pages; **read Chapter 1 (~1h), Chapter 3 (~1h), Chapter 6 §6.3
  "Computing Value-at-Risk" (~2h), Chapter 11 "Performance assessment" (~1h).**
- **Take from it:** this is the document that *invented industrial VaR*, and it is written
  by practitioners for practitioners in 1996 — before VaR became a textbook topic, so it
  explains its own motivation. Verified TOC landmarks:
  - Ch. 1 "Introduction" — §1.1 "An introduction to Value-at-Risk and RiskMetrics."
  - Ch. 3 "Applying the risk measures" — §3.1 "Market risk limits", §3.3 "Performance
    evaluation", §3.4 "Regulatory reporting, capital requirement".
  - Ch. 6 "Market risk methodology" — §6.1 identifying exposures, §6.2 mapping cash flows,
    **§6.3 "Computing Value-at-Risk"**, §6.4 examples.
  - Ch. 8 §8.3 "The properties of correlation (covariance) matrices and VaR".
  - Ch. 11 "Performance assessment" — backtesting a VaR model against realised P&L.
- **This document is also load-bearing for Track C** — see C2.

### B4. BCBS, "Supervisory framework for the use of 'backtesting' …" (January 1996)

- Basel Committee on Banking Supervision, January 1996.
  **https://www.bis.org/publ/bcbs22.pdf** (verified, HTTP 200, free)
- **Free. ~1.5 hours** (~15 pages, but dense; read "Statistical considerations in defining
  the zones" and "Definition of the green, yellow, and red zones" carefully).
- **Take from it — this is the answer to "how do you know your 99% VaR is right?":**
  a 99% VaR model observed over 250 days should produce about 2.5 exceptions. The Committee
  refuses to use a single threshold *because there isn't one that gives both a low false-
  rejection rate and a low false-acceptance rate*, and instead defines three zones from the
  binomial distribution:
  - **Green: 0–4 exceptions.** Consistent with an accurate model.
  - **Yellow: 5–9 exceptions.** Boundary chosen as the point where P(that many or fewer) ≥
    95%; for 250 observations at true 99% coverage, "five or fewer exceptions will be
    obtained 95.88% of the time", so the yellow zone begins at five.
  - **Red: 10+ exceptions.** Boundary chosen as the point where P(that many or fewer) ≥
    99.99%.
  (All four bullets above are direct readings of the document's §(c) and Table 2.)
- **Directly implementable in M11.** The subject demands a test "VaR avec et sans netting
  cross-exchange". Add a second test: replay your recorded oracle series, compute rolling
  99% VaR, count exceptions over 250 windows, and assert the count lands in the green zone.
  That is a *real* validation of your VaR, not a smoke test, and it is a regulator's own
  criterion. It is the single highest-value thing on this list for turning M8 from
  "computed a number" into "validated a model."

### B5. Artzner, Delbaen, Eber & Heath, "Coherent Measures of Risk" (1999)

- Philippe Artzner, Freddy Delbaen, Jean-Marc Eber, David Heath, *Mathematical Finance*,
  Vol. 9, No. 3 (July 1999), pp. 203–228.
  https://onlinelibrary.wiley.com/doi/10.1111/1467-9965.00068
- **Paid** at Wiley. An author-uploaded copy exists on Delbaen's ResearchGate profile
  (https://www.researchgate.net/profile/Freddy-Delbaen/publication/227614132_Coherent_Measures_of_Risk)
  — author self-archiving, so legitimate, but ResearchGate requires an account and I did
  not verify the file.
- **~3 hours** for §1–§3 and the axioms. The rest is measure theory you can skip.
- **Take from it:** the four axioms — monotonicity, translation invariance, positive
  homogeneity, **subadditivity** — and the precise statement of subadditivity:
  `R(L1 + L2) ≤ R(L1) + R(L2)`, i.e. *merging two portfolios cannot create risk*. VaR
  satisfies the other three and can violate this one. This is the theoretical spine of
  Track C; read it *after* C1, which explains why you should care.
- **Optional if you are not mathematically inclined** — C1 (below) states everything you
  need and is free.

### B6. Acerbi & Tasche, "On the coherence of expected shortfall" (2002)

- Carlo Acerbi & Dirk Tasche, *Journal of Banking & Finance*, Vol. 26, No. 7, pp. 1487–1503.
  **Free preprint: https://arxiv.org/abs/cond-mat/0104295** (verified — title and authors
  confirmed on the arXiv abstract page).
- **Free (preprint). ~2 hours.**
- **Take from it:** the definition of ES that is coherent *for all distributions* including
  discontinuous ones, and why the several plausible-looking definitions of "average loss
  beyond VaR" are not equivalent when your loss distribution has atoms. **Your simulated
  loss distribution from 200–1000 discrete agents will absolutely have atoms**, so this is
  not academic hair-splitting for CrashLab: naively averaging "the returns worse than the
  99th percentile" over a finite sample can silently disagree with the coherent definition
  when ties straddle the cut-off.
- **Practical rule to code:** with *N* sorted losses and level α, take
  `ES = (1/⌈(1-α)N⌉) * sum of the ⌈(1-α)N⌉ largest losses`, and write a test for the case
  where `(1-α)N` is not an integer and for the case where several losses tie at the cut-off.

### B7. Danielsson, *Financial Risk Forecasting* — code companion

- Jon Danielsson, Wiley 2011. **Book is paid.** ISBN 9780470669433.
- **Companion site https://www.financialriskforecasting.com/ is free** and (verified today)
  offers per-chapter implementations in **R, Python, Julia and MATLAB**, lecture slides,
  ~100 seminar questions with solutions, an R notebook on practical implementation, and an
  errata page.
- **Free (the code and slides). ~2–3 hours** to work through the risk-measure chapters'
  code.
- **Take from it:** working reference implementations of historical simulation VaR and ES to
  check your own against. Even without the book, the code plus slides is enough to
  cross-validate your numbers, which is exactly what you want before claiming an M8 figure
  is correct. Use it as a **test oracle**, not as a teaching text.

---

## Track C — Aggregation and netting (soutenance Q8)

This is the track the ticket flags hardest, and the one with the best free primary sources.
The subject's exact wording: *"Les positions A et B sur le même sous-jacent doivent être
dédupliquées avant l'agrégation. Additionner aveuglément VaR_A et VaR_B est considéré
incorrect lorsque les positions se couvrent."*

### C1. BCBS Working Paper No. 19, "Messages from the academic literature on risk measurement for the trading book" (31 January 2011)

- Basel Committee on Banking Supervision, Working Paper No. 19.
  **https://www.bis.org/publ/bcbs_wp19.pdf** (verified, HTTP 200, free)
- **Free.** Full document ~55pp. **Read §3 "Risk measures" (pp. 17–25) and §5 "Unified
  versus compartmentalised risk measurement" (pp. 29–37). ~3 hours** for those two sections.
- **This is the single most important source on this list for Q8.** It is a regulator's own
  literature survey, it is free, and it says exactly what you need, in language you can
  quote.

  Verified TOC of the two relevant sections:
  - §3 Risk measures: 3.1 Overview, 3.2 VaR (p.17), 3.3 Expected shortfall (p.20),
    3.4 Spectral risk measures (p.23), 3.5 Other risk measures, 3.6 Conclusions.
  - §5 Unified versus compartmentalised risk measurement: 5.1 Overview (p.29),
    **5.2 Aggregation of risk: diversification versus compounding effects (p.30)**,
    5.3 "bottom-up" approach, 5.4 "top-down" approach, 5.5 Conclusions.

- **Take from it — four things, all quotable:**

  1. **Why subadditivity is the property that makes decentralised risk limits work.** The
     paper's own framing (§3.2): a manager who wants total loss `L = L1 + L2` bounded by *M*
     can, *if the risk measure is subadditive*, delegate by imposing `R(Li) ≤ Mi` on each
     desk with `ΣMi = M`. "Subadditivity makes decentralisation of risk-management systems
     possible." **This is precisely the CrashLab architecture**: two exchanges, two desks,
     one aggregate risk budget.

  2. **Naive addition is *usually* conservative but not reliably so — and it is the wrong
     kind of wrong.** Verbatim from §5.2:
     > "If the risks associated with these books are distinct, even if they are not
     > independent, then adding the VaR measures of these books will be conservative. If the
     > risks associated with the two books are not distinct, (eg if the separation is due
     > only to accounting rules), then adding compartmentalised VaR risk measures is
     > guaranteed to be conservative only if all risks relevant to each book are accounted
     > for. If not, the sum of compartmentalised risk measures may understate the risk of
     > the combined portfolio risk."

     and the flat conclusion:
     > "it is always questionable to calculate different risks for the same portfolio in a
     > compartmentalised fashion and to hope that adding up the compartmentalised measures
     > will be a conservative estimate of the true risk. In general, it will not be."

     **CrashLab's A and B are the "not distinct" case**: same underlying, separated only by
     which venue booked the trade. That is literally the paper's "separation due only to
     accounting rules."

  3. **VaR's subadditivity failure is not a toy.** §3.2 subsection "Is VaR failing
     subadditivity relevant in practice?" — verified content: VaR *is* subadditive when the
     joint distribution of risk factors is elliptical (multivariate normal etc.), citing
     McNeil, Frey & Embrechts (2005) Theorem 6.8; McNeil et al. also construct a *continuous*
     two-dimensional counter-example (their Example 6.22, p.253) where VaR is superadditive;
     Danielsson et al. (2005) prove subadditivity only asymptotically for sufficiently high
     confidence with finite mean; and Degen, Embrechts & Lambrigger (2007) find 99% VaR
     **superadditive for tail indices above 6**, which the paper calls "realistic cases in
     market risk." Its own conclusion: the conditions that guarantee VaR subadditivity "are
     generally not fulfilled in the market risk context."

  4. **Diversification benefit depends on the level of aggregation** (§5.2): benefits show up
     at high levels of aggregation; at the individual-portfolio level, risk *compounding*
     can dominate. Useful nuance if an examiner pushes.

- **How to use this at the soutenance:** you now have a regulator-authored statement that
  both (a) `VaR_A + VaR_B` overstates risk when the positions hedge, and (b) it can also
  *understate* risk in exactly the structural situation CrashLab has. Both directions of
  wrongness, from one free PDF.

### C2. RiskMetrics Technical Document §3.1 and §3.4.1 (see B3 for the URL)

- **Free. ~30 minutes** for these two short sections.
- **Take from it — two quotable primary statements:**
  - **§3.1 "Market risk limits", with Chart 3.1 "Hierarchical VaR limit structure"** (a
    business area with a $20MM VaR limit above groups limited to $10MM + $12MM + $8MM = $30MM):
    > "A further advantage of Value-at-Risk limits comes from the fact that VaR measures
    > incorporate portfolio or risk diversification effects. This leads to hierarchical limit
    > structures in which the risk limit at higher levels can be lower than the sum of risk
    > limits of units reporting to it."

    **This chart is the picture to put in your VaR report.** It is exactly the CrashLab
    A/B/aggregate structure and it shows, from 1996, that the aggregate limit being *below*
    the sum of the parts is the intended design, not an anomaly.
  - **§3.4.1 "Capital Adequacy Directive"** — the historical example of a regulator getting
    this wrong. Verbatim:
    > "In a nutshell the EC-CAD computes the capital requirement as a sum of capital
    > requirements on positions of different types in different markets. It does not take
    > into account the risk reducing effect of diversification. As a result, the strict
    > application of the current recommendations will lead financial institutions … to
    > overestimate their market risks and consequently be required to maintain very high
    > capital levels."

    **This is your "not a toy concern" evidence.** A European legislative directive summed
    compartmentalised risk numbers, and the industry's flagship risk methodology document
    called it out in print for over-estimating risk. Naive addition of risk numbers is a
    documented institutional mistake with a name and a date.

### C3. Embrechts, McNeil & Straumann, "Correlation and Dependence in Risk Management: Properties and Pitfalls"

- Paul Embrechts, Alexander J. McNeil, Daniel Straumann. ETH Zürich. Published in
  *Risk Management: Value at Risk and Beyond* (CUP, 2002); the widely circulated ETH working
  paper version is free:
  **https://www.risknet.de/fileadmin/eLibrary/Embrechts-Correlations-1999-ETH-Paper.pdf**
  (verified HTTP 200 — note this is a third-party e-library mirror of the ETH paper, not
  ETH's own server; content is the ETH working paper).
- **Free. ~3 hours.**
- **Take from it:** the "fallacies of correlation." The one that matters for CrashLab: a
  single correlation number does **not** determine the joint distribution, and reasoning that
  works in the elliptical (multivariate-normal) world silently fails outside it. Concretely:
  if you aggregate `VaR_A` and `VaR_B` using the two-asset formula
  `VaR_p = sqrt(VaR_A² + VaR_B² + 2ρ·VaR_A·VaR_B)`, you have assumed ellipticality. That
  formula is *fine as a cross-check* and *wrong as a primary method* for a crash scenario
  where the whole point of M7 is that tails move together in a way normal distributions do
  not reproduce.
- **This gives you the strongest form of the Q8 answer:** the objection to `VaR_A + VaR_B` is
  not merely "you forgot correlation" — because the correlation-based fix has its *own*
  hidden assumption, and CrashLab's cascade scenario is designed to break it.

### C4. Joint Forum (BCBS/IOSCO/IAIS), "Developments in Modelling Risk Aggregation" (October 2010)

- Bank for International Settlements, 21 October 2010.
  **https://www.bis.org/publ/joint25.pdf** (verified, HTTP 200, free)
  Landing page: https://www.bis.org/publ/joint25.htm
- **Free.** ~50pp. **~2 hours**, and honestly skimmable.
- **Take from it:** supervisory evidence that risk aggregation is genuinely hard in practice
  — the report's findings include that firms' aggregation models "have not adapted to support
  all the functions and decisions for which they are now used", that firms "may not fully
  understand the risks they face, including tail events", and that supervisors generally do
  not rely on these models, considering them a work in progress.
  (I read these findings from the BIS landing page and press release
  https://www.bis.org/press/p101021.htm; I did **not** page through the full PDF.)
- **Optional.** Read it only if you want to say at the soutenance "and the supervisors
  themselves say nobody has fully solved this." It is a strong closing line but it is not
  needed to answer Q8.

### C5. The method you should actually implement (synthesis, not a source)

Nothing above tells you the algorithm in one place, so here it is, assembled from B2 (Hull
Ch. 13), B3 (RiskMetrics §6.3) and C1. Verify it against those sources rather than trusting
this summary.

**Correct cross-exchange netted historical VaR:**

1. Take the recorded oracle return series `r_1 … r_N` (the subject says "à partir des
   rendements de l'oracle enregistré" — one shared risk factor, BTC-USD).
2. Compute the **net** exposure to that factor:
   `net_delta = delta_A + delta_B + option_delta` — this is the subject's own
   `net_btc_delta`, and it is the deduplication step ("dédupliquées avant l'agrégation").
   A +10 BTC position on A and a −10 BTC position on B is `net_delta = 0`.
3. For each historical return, revalue: `PnL_i = net_delta * S_0 * r_i` (linear case;
   full revaluation if options are present, since option P&L is not linear in `r`).
4. Sort the `PnL_i`, take the 1st-percentile loss. That is `VaR_net_99`.
5. Separately compute `VaR_A` and `VaR_B` the same way using `delta_A` and `delta_B` alone,
   and publish `VaR_A + VaR_B` as the **naive sum**, as the subject explicitly demands.
6. Publish `diversification_benefit = (VaR_A + VaR_B) − VaR_net`.

**The property that makes it correct, and the one-line reason:** because you built a single
P&L series for the *combined* portfolio and took *one* quantile of *that* series, the
offsetting positions cancel *inside each scenario*, before the quantile is taken. Naive
addition takes the quantile first and adds after — and **the quantile operator is not
additive**. `Q(X+Y) ≠ Q(X) + Q(Y)`; `Q(X)+Q(Y)` is the value you would get only if A's worst
day and B's worst day were guaranteed to be the same day, in the same direction. When the
positions hedge, A's worst day *is* B's best day, and adding the two quantiles asserts the
exact opposite of the truth.

**Test to write for M11** ("VaR avec et sans netting cross-exchange"):
- perfectly offsetting positions (`delta_A = −delta_B`, no option) ⟹ `VaR_net ≈ 0` while
  `VaR_A + VaR_B > 0`. Assert the gap.
- identical same-sign positions ⟹ `VaR_net ≈ VaR_A + VaR_B`. Assert near-equality — this is
  the boundary case where the naive sum is *right*, and knowing when it's right is what
  proves you understand why it's usually wrong.
- an intermediate hedge ratio ⟹ `VaR_net` strictly between. Assert monotonicity in the hedge
  ratio.

---

## Track D — Drawdown, delta, inventory

### D1. Magdon-Ismail & Atiya, "An Analysis of the Maximum Drawdown Risk Measure" (2004)

- Malik Magdon-Ismail (RPI) & Amir F. Atiya. Published as "Maximum drawdown", *Risk*,
  October 2004. **Free author PDF:
  https://www.cs.rpi.edu/~magdon/ps/journal/drawdown_RISK04.pdf** (verified, HTTP 200)
  Companion talk slides: https://www.cs.rpi.edu/~magdon/talks/mdd_NYU04.pdf
- **Free. ~1.5 hours.**
- **Take from it:** the definition — MDD is the largest peak-to-trough decline of the equity
  curve — and, crucially, the *distributional* result: for a Brownian motion with drift, the
  expected maximum drawdown has a closed form that **grows with the observation window**.
  That is the fact that makes MDD a different kind of statement from VaR:
  - **VaR** is a statement about *one period*, with a *stated probability*, about *today's*
    position. It answers "how bad can tomorrow be?"
  - **MDD** is a statement about a *whole realised path*, with *no probability attached*,
    about a *history*. It answers "how bad did the worst stretch actually get?"
  - Consequently MDD is **not comparable across runs of different length**. A 1000-step
    backtest will show a larger MDD than a 100-step one for the same strategy, purely
    mechanically. If your M7 report compares agents, they must be compared over identical
    windows.
- **This is the answer to "why is MDD a different kind of statement from VaR?"** — one is a
  quantile of a one-period distribution, the other is a functional of a path with a
  length-dependent expectation.

### D2. Hull, *Options, Futures, and Other Derivatives* — Chapter 19, "The Greek Letters"

- John C. Hull, Pearson. 11th ed. 2021, ISBN 9780136939917.
  https://www.pearson.com/en-us/subject-catalog/p/options-futures-and-other-derivatives/P200000005938/9780136939917
  (Chapter 19 = "The Greek Letters" confirmed for the 11th edition.)
- **Paid.** **~4 hours** for Ch. 19; add Ch. 15 (Black–Scholes–Merton) if M9's pricing is new
  to you.
- **Take from it, in this order of importance for CrashLab:**
  - **Delta as ∂V/∂S** — the sensitivity of a position's value to a $1 move in the
    underlying. For a linear position (a perp) delta is just the signed size; for an option
    it is `N(d1)` for a call. That is all `net_btc_delta = delta_A + delta_B + option_delta`
    means: *add up everything's sensitivity to the same underlying and see what is left*.
    It is the same deduplication idea as Track C, one derivative lower.
  - **Delta-neutrality and rebalancing** — Hull's worked delta-hedging simulation tables are
    the model for M9's `LongVolAgent`, and they show the thing you must be able to say out
    loud: **delta hedging is not free and is not exact**. Delta changes as the price moves
    (that is gamma), so a delta-hedged book must be re-hedged, and each re-hedge costs
    spread and fees. That is the direct link to M7's **"Time unhedged"** metric: the metric
    exists because you cannot be continuously hedged, only intermittently, and the time you
    spend outside your delta band is a real, measurable exposure.
  - Gamma and vega, enough to state why the `ShortVolAgent` needs a gamma limit.
- **Scope note:** you need Ch. 19 for M8's `net_btc_delta` and M9's hedging. You do not need
  the volatility-surface chapters — the subject explicitly says no full surface.

### D3. Inventory risk (pointer, likely owned by issue 03)

The M7 metric **"Inventory peak"** and the market maker's unhedged-risk question
(soutenance Q6) are inventory-risk topics from market microstructure — Ho & Stoll's
inventory models and, in the modern practitioner line, Avellaneda & Stoikov's
"High-frequency trading in a limit order book" (2008). **I did not verify URLs or editions
for these** because they belong to issue 03 (order books / microstructure). Check that
ticket's reading list before buying anything here; if it does not cover inventory risk,
raise it there rather than duplicating it in M8's list.

---

## Track E — Latency is a distribution (soutenance Q7)

Everything in this track is **free**. Total ~6–8 hours. Do this track first if you do
nothing else. M11 demands `count, min, mean, p50, p95, p99, p99.9, max` for five pipeline
stages, and this track tells you both how to produce those numbers and why the list is
written that way.

### E1. Gil Tene, "How NOT to Measure Latency" (talk)

- Gil Tene (CTO/co-founder, Azul Systems).
  **InfoQ recording: https://www.infoq.com/presentations/latency-response-time/** — verified:
  recorded at **QCon San Francisco 2015**, published 26 March 2016, **54:23**.
  Also on YouTube (Strange Loop version): https://www.youtube.com/watch?v=lJ8ydIuPFeU
  The talk has been given at multiple conferences (QCon London 2013, Strange Loop, USI);
  any recording is fine.
- **Free. ~1 hour**, plus an hour re-watching the coordinated-omission segment. In the
  Strange Loop recording the coordinated omission material starts around 33:50.
- **Watch this before reading anything else in Track E.**
- **Take from it — this *is* the answer to soutenance Q7:**
  - **Latency is not a number, it is a distribution, and the distribution is strongly
    multi-modal.** There is a fast path (cache hit, no contention), a slower path (lock
    contention, syscall), and a much slower path (GC pause, page fault, scheduler
    preemption). A mean sits in a valley *between* modes and describes nothing that ever
    actually happened.
  - **The mean answers a question nobody asks.** Nobody experiences the average latency. In
    a request path made of *k* sequential internal calls, the probability of a request
    seeing *only* fast responses is `p_fast^k` — so the fraction of *requests* that touch at
    least one slow component is far higher than the fraction of *operations* that are slow.
    The mean hides exactly the events that determine what users and counterparties see.
  - **Standard deviation is meaningless here.** It presumes a single-moded, roughly symmetric
    distribution. Latency is neither. Reporting "mean ± σ" for latency is a category error.
  - **Percentiles must be reported at the level where the requirement lives.** p99 is not
    "almost everything"; if you serve 1000 messages/second, p99 is 10 events per second in
    the tail. p99.9 and max are where the interesting failures live — which is exactly why
    the subject demands p99.9 and max, not just p50 and p95.
  - **The maximum is a real measurement, not an outlier.** It is the only percentile you can
    state with certainty from a finite sample, and it is what bounds your worst case.
- **Q7 answer in one sentence** (memorise something like this):
  *"Because latency is a multi-modal distribution whose modes come from qualitatively
  different code paths — fast path, contention, and stalls — the mean falls in a gap between
  modes and describes no real event; the numbers that matter operationally are the tail
  percentiles and the maximum, because a request that touches k components sees the tail far
  more often than any individual component does."*

### E2. Gil Tene, the original "Coordinated Omission" post

- mechanical-sympathy Google Group thread:
  **https://groups.google.com/g/mechanical-sympathy/c/icNZJejUHfE/m/BfDekfBEs_sJ**
  (verified — Tene's explanation is in this thread)
- **Free. ~45 minutes** including working the arithmetic yourself.
- **Take from it — the single most likely way your M11 benchmark will lie to you:**
  - **The mechanism.** A load generator that sends a request, *waits* for the response, then
    sends the next one, cannot issue requests while the system is stalled. If it intends one
    request per millisecond and one request takes 536ms, then ~535 requests that *should*
    have been issued during that stall were never sent — and the ~535 bad measurements they
    would have produced are silently absent from your histogram.
  - **Why "coordinated."** The omission is not random: it is *coordinated with the system's
    bad behaviour*. You only drop samples exactly when the system is at its worst. Tene's
    own framing: "we are only omitting the 'very bad results' (results that are larger than
    1msec. I.e. larger than 200x the average latency)."
  - **The magnitude.** Tene reports that reported 99.99th percentiles can be understated by
    factors on the order of 10,000×–35,000× under coordinated omission. This is not a 10%
    error; it is a wrong-by-orders-of-magnitude error, and it always errs in the flattering
    direction.
  - **The conceptual fix:** distinguish **service time** (how long the system took once it
    started) from **response time** (how long from when the request *should have been
    issued*). A benchmark harness must measure against the *intended* schedule, not against
    when it happened to get around to sending.
- **Direct consequence for CrashLab M11.** Your five benchmarks —
  `gateway → matching`, `matching → trade publication`, `trade → position update`,
  `mark update → liquidation decision`, `agent decision → fill end-to-end` — are exactly the
  shape of measurement that coordinated omission destroys, because a naive harness will
  generate the next order only after the previous one is acknowledged. **Drive the load from
  a fixed schedule** (a pre-computed sequence of intended send times), and when a send is
  late, timestamp it against the *intended* time. Say this at the soutenance; it is a
  measurement-discipline answer that generalises Q7 beyond "use percentiles."

### E3. HdrHistogram

- **Java reference implementation: https://github.com/HdrHistogram/HdrHistogram**
  — verified: **CC0-1.0 licence**; README documents
  `recordValueWithExpectedInterval()` and the coordinated-omission correction (it
  synthesises the missing intermediate values, "linearly decreasing in steps"); histogram
  precision is configured as a dynamic range plus significant figures (the README's example
  tracks 0–3,600,000,000 at 3 significant digits, i.e. 1µs resolution up to 1ms, scaling up
  to hours); **memory footprint is constant with no allocation during recording**;
  percentiles are read out via `HistogramData.percentiles()` / `PercentileIterator`.
  Ports exist for C, C#/.NET, Python, JavaScript, Rust, Erlang and Go.
- **C port (this is the one for Exchange A):
  https://github.com/HdrHistogram/HdrHistogram_c** — verified: CC0-1.0, CMake build, exposes
  `hdr_init`, `hdr_record_value`, `hdr_record_values`,
  **`hdr_record_corrected_value`** (the coordinated-omission-correcting variant), and
  `hdr_percentiles_print` with CLASSIC and CSV output.
- **Free. ~2 hours** to read the README, build the C port, and record a synthetic
  distribution.
- **Take from it, and why it is the right tool rather than a nice-to-have:**
  - **Constant-time, allocation-free recording.** You are measuring a matching engine. If
    your instrumentation allocates or takes a lock on the hot path, it perturbs the very
    thing it measures. HdrHistogram is designed for exactly this constraint.
  - **You cannot get p99.9 from a running mean and variance,** and you cannot get it by
    keeping the last N samples either. You need the whole distribution, at bounded memory,
    at known precision. That is what this library is.
  - **It has the coordinated-omission correction built in** (`hdr_record_corrected_value`),
    so E2's fix is a one-line change once you know the expected interval.
  - **Precision is a stated guarantee, not a hope** — "3 significant figures" is an explicit
    contract you can quote in your benchmark report.
- **Do not write your own percentile code for M11.** Using HdrHistogram *and being able to
  explain why* is a better answer than a hand-rolled sorted vector, and it costs you an
  afternoon.

### E4. Dean & Barroso, "The Tail at Scale" (2013)

- Jeffrey Dean & Luiz André Barroso, *Communications of the ACM*, Vol. 56, No. 2 (February
  2013), pp. 74–80. DOI 10.1145/2408776.2408794.
  **Free author copy: https://www.barroso.org/publications/TheTailAtScale.pdf** (verified,
  HTTP 200). Also free at https://cacm.acm.org/research/the-tail-at-scale/ (CACM blocked my
  automated fetcher with 403 but the article is open access in a browser).
- **Free. ~1.5 hours.** It is 7 pages and worth reading twice.
- **Take from it:**
  - **Tail latency amplifies with fan-out.** If a request must touch 100 components and each
    has a 1%-of-the-time slow path, then ~63% of requests are slow. Component-level p99
    becomes system-level typical. This is the quantitative version of E1's argument.
  - **Where tail latency comes from:** shared resource contention, background daemons,
    queueing, garbage collection, power management, maintenance activities. It is not a bug
    to be fixed once; it is a property to be engineered around.
  - **Tail-tolerant techniques** — hedged requests, tied requests, micro-partitioning,
    selective replication. You will not implement these in CrashLab, but knowing they exist
    lets you answer "so what would you do about a bad p99.9?" with something better than
    "optimise the code."
- **Relevance to CrashLab:** your `agent decision → fill end-to-end` benchmark is a fan-out
  path across gateway, matching, publication and position update. This paper is why the
  end-to-end p99.9 will be much worse than the sum of the component p99.9s, and why that is
  expected rather than a bug.

### E5. Baron Schwartz, "Why Percentiles Don't Work the Way You Think"

- Baron Schwartz, VividCortex (now SolarWinds), 18 November 2016.
  https://orangematter.solarwinds.com/2016/11/18/why-percentiles-dont-work-the-way-you-think/
  (also republished at https://www.solarwinds.com/blog/why-percentiles-dont-work-the-way-you-think)
- **Free. ~20 minutes.**
- **Take from it, and it is one sharp point:** **you cannot average percentiles.** Monitoring
  systems routinely compute p99 per interval, store the p99 as a time series, and then
  *average or downsample those p99 values* — which is mathematically meaningless, because a
  percentile is a position statistic that requires the underlying population. The only
  correct way to get a p99 over a longer window is to merge the underlying distributions
  (which is another argument for E3: HdrHistogram histograms *are* mergeable, and merging
  them is exact).
- **Directly relevant to M11.** You will run benchmarks in repetitions. If you report
  "average p99 across 10 runs" you have committed exactly this error. Merge the histograms
  and take one p99 of the merged data — and say so in your benchmark report.

### E6. Gregg, *Systems Performance* (2nd edition) — Chapters 2 and 12

- Brendan Gregg, *Systems Performance: Enterprise and the Cloud*, 2nd ed., Addison-Wesley,
  2020. ISBN 9780136820154. Author's page:
  https://www.brendangregg.com/systems-performance-2nd-edition-book.html
- **Chapter 2, "Methodologies"** — especially **§2.3 Concepts** (latency, utilisation,
  saturation), **§2.5 Methodology**, **§2.8 Statistics** (averages, percentiles, multimodal
  distributions), **§2.10 Visualizations**.
  **Chapter 12, "Benchmarking"** — §12.1 Background, §12.2 Benchmarking Types,
  **§12.3 Methodology**, §12.4 Benchmark Questions.
  (Section structure of Ch. 2 and Ch. 12 verified from the published TOC.)
- **Paid.** **~5 hours** for those two chapters.
- **Take from it:**
  - Ch. 2 §2.8 gives you the statistics discipline behind E1 in textbook form, plus the
    visualisations (latency heat maps, frequency trails) that make multi-modality *visible*.
    A heat map in your M11 report is worth more than a table of seven numbers, because it
    shows the modes.
  - Ch. 12 is the benchmarking-methodology chapter you have never read because you have no
    benchmarking background. It catalogues the ways benchmarks lie — measuring the wrong
    thing, warm-up effects, unrealistic workloads, ignoring variance, benchmarking a
    misconfigured system — and gives the **"benchmark questions"** checklist for
    interrogating any number. Also read Gregg's **"Active Benchmarking"** methodology: while
    the benchmark runs, use system tools to confirm that the thing you *think* is the
    bottleneck actually is. That is the discipline behind the subject's "une optimisation
    doit être mesurée avant/après avec résultats fonctionnels identiques."
- **This is the one paid item in Track E and the only general benchmarking text on this
  list.** Given the reader has no benchmarking background at all, I would buy it.

### E7. Ousterhout, "Always Measure One Level Deeper" (2018)

- John Ousterhout, *Communications of the ACM*, Vol. 61, No. 7 (July 2018), pp. 74–83.
  DOI 10.1145/3213770 — https://dl.acm.org/doi/10.1145/3213770
  **Free full text at CACM: https://cacm.acm.org/research/always-measure-one-level-deeper/**
  (open access; my automated fetcher got a 403 but it is readable in a browser). A course
  mirror exists at `https://rcs.uwaterloo.ca/~ali/cs854-f23/papers/onelevel.pdf` — **that URL
  did not respond to my check today**, so treat it as unverified.
- **Free. ~1 hour.**
- **Take from it:** the title is the thesis — to understand performance at one level you must
  also measure the level below, i.e. the *underlying factors that produce* the number. The
  paper catalogues the standard failure modes: measuring only the top-level metric,
  measuring too little, not understanding *why* the number is what it is, and reporting
  results that are "more marketing than science."
- **This is the source behind soutenance Q9** ("Quelle optimisation avez-vous mesurée et non
  simplement supposée ?"). The defensible answer has the shape: *"I measured the top-level
  p99 of `mark update → liquidation decision`, then measured one level deeper — cache misses
  / allocation counts / lock wait time — to identify why; I changed X; the deeper metric
  moved in the predicted direction and the top-level p99 followed, with identical functional
  results."* Without the deeper measurement you cannot distinguish a real improvement from
  noise or from a coincidence.

### E8. Georges, Buytaert & Eeckhout, "Statistically Rigorous Java Performance Evaluation" (OOPSLA 2007)

- Andy Georges, Dries Buytaert, Lieven Eeckhout, Ghent University. OOPSLA 2007 /
  *ACM SIGPLAN Notices* 42(10).
  **Free author copy: https://dri.es/files/oopsla07-georges.pdf** (verified, HTTP 200)
- **Free. ~2 hours.**
- **Take from it:** despite the "Java" in the title, the statistical content is
  language-agnostic and it is the standard citation for *how to report a benchmark honestly*:
  run multiple times, report **confidence intervals** rather than a single number, and use a
  statistical test before claiming that version B is faster than version A. It also
  demonstrates that many published performance comparisons flip their conclusions once
  measurement noise is handled properly.
- **Relevance:** the subject's before/after optimisation requirement is precisely a
  two-sample comparison. This paper tells you the standard for making that claim
  defensibly. **If you are short of time, read only §3–§4.**

### E9. Google Benchmark user guide (tooling, C++ side)

- **https://github.com/google/benchmark/blob/main/docs/user_guide.md** (verified)
- **Free. ~1 hour.**
- **Take from it, three specific things:**
  - **Repetitions and aggregate statistics** — `--benchmark_repetitions` / `Repetitions()`;
    the library reports mean, median, standard deviation and coefficient of variation across
    repetitions, and `ComputeStatistics()` lets you register **custom statistics** (this is
    how you add p95/p99/p99.9 rather than settling for mean/median).
  - **`--benchmark_report_aggregates_only` / `--benchmark_display_aggregates_only`** — the
    difference matters: the first drops per-run data everywhere, the second only from the
    console while keeping full detail in the JSON/CSV file. Use the second, and archive the
    JSON, so your M11 report is reproducible from raw data.
  - **`benchmark::DoNotOptimize()` and `benchmark::ClobberMemory()`** — the guide's own
    framing: `DoNotOptimize` forces the *result* of an expression to be stored in memory or a
    register and acts as a read/write barrier for global memory; `ClobberMemory` forces all
    pending writes to global memory. **Without these your C++ microbenchmark may measure
    nothing at all**, because the optimiser deletes the code you were timing. This is a
    concrete, demonstrable trap and a good thing to show an examiner.
- **Python side:** `pytest-benchmark` for Exchange B. I did not verify its documentation
  URL or feature set in this research pass — check it yourself.

### E10. Bakhvalov, *Performance Analysis and Tuning on Modern CPUs* — optional

- Denis Bakhvalov et al. **Source repository, CC0-1.0 licence:
  https://github.com/dendibakh/perf-book** (verified: CC0-1.0; the repo contains the full
  Markdown/LaTeX source and build instructions for producing the PDF). A free PDF of the
  2nd edition was released by the author in November 2024; the repository is the
  authoritative place to get it.
- **Free. ~10+ hours** for the whole book; **~2 hours** for the measurement chapters.
- **Take from it:** the chapters on measuring performance and on noise in measurements —
  why measurements on a modern CPU are non-deterministic (frequency scaling, address-space
  layout, cache state, NUMA), and what you must control before before/after numbers mean
  anything. **Read this only if your M11 optimisation work stalls on unreproducible
  measurements.** It is not required for the milestone.
- **Caveat:** I verified the repository, licence and that a PDF build is provided; I did
  **not** verify individual chapter titles or numbering. Do not cite chapter numbers from
  this book without opening it.

---

## Track F — Pre-trade risk controls, and the incidents that created them

The ticket's premise is correct: **most of these controls exist because something went wrong
once.** This track gives you a named source and, where one exists, a named incident for each
of the subject's ten controls.

### F1. SEC, *In the Matter of Knight Capital Americas LLC* (16 October 2013)

- U.S. Securities and Exchange Commission, Exchange Act Release No. **34-70694**,
  Administrative Proceeding File No. **3-15570**, 16 October 2013.
  https://www.sec.gov/files/litigation/admin/2013/34-70694.pdf
  (SEC.gov blocks automated fetchers with 403; it opens fine in a browser. I read the
  document via the mirror at http://www.headlandstech.jp/static/file/34-70694.pdf and all
  facts below are quoted or closely paraphrased from the order's own text.)
- **Free. ~2 hours.** It is ~20 pages of plain English and it reads like a post-mortem.
- **Read this before anything else in Track F.** It is the best single document on this
  entire list for making pre-trade controls feel necessary rather than bureaucratic.

- **What happened, from the order itself:**
  - **1 August 2012.** Knight's order router SMARS, "while processing 212 small retail orders
    that Knight had received from its customers, … routed millions of orders into the market
    over a 45-minute period, and obtained over 4 million executions in 154 stocks for more
    than 397 million shares." Net long ~$3.5bn in 80 stocks, net short ~$3.15bn in 74 stocks.
    **"Knight lost over $460 million from these unwanted positions."**
  - **The technical cause (¶13–16).** New code for the NYSE Retail Liquidity Program was
    meant to replace long-dead "Power Peg" code, and **repurposed the flag that activated
    Power Peg**. Power Peg had been unused since 2003, but remained "present and callable."
    In 2005 the cumulative-quantity tracking that told Power Peg to stop routing child orders
    once the parent was filled had been **moved to an earlier point in the code sequence**,
    and **Power Peg was never retested after that move**. During deployment "one of Knight's
    technicians did not copy the new code to one of the eight SMARS computer servers … Knight
    did not have a second technician review this deployment … Knight had no written
    procedures that required such a review." On 1 August the seven updated servers behaved;
    the eighth ran Power Peg, which "continuously sent child orders, in rapid sequence, for
    each incoming parent order without regard to the number of share executions Knight had
    already received."
  - **The missed warning (¶19).** From ~08:01 ET, an internal system generated 97 automated
    "BNET reject" e-mails referencing SMARS and the error **"Power Peg disabled"** — before
    the 09:30 open. "Knight did not design these types of messages to be system alerts, and
    Knight personnel generally did not review them."
  - **The incident response made it worse (¶27).** "Knight relied primarily on its technology
    team to attempt to identify and address the SMARS problem in a live trading environment
    … In one of its attempts to address the problem, Knight uninstalled the new RLP code from
    the seven servers where it had been deployed correctly. **This action worsened the
    problem**, causing additional incoming parent orders to activate the Power Peg code."

- **The control failures, mapped onto CrashLab's ten checks.** These are the order's own
  findings (¶20–26):
  - **Controls existed upstream but not at the last hop (¶20–21).** "Knight's customer
    interface, internal order management system, and system for internally executing customer
    orders all contained controls concerning the prevention of the entry of erroneous
    orders. **However, Knight did not have adequate controls in SMARS**." → *your ten checks
    must run at the last gate before the book, not only in the agent.*
  - **No output/input reconciliation (¶21).** "Knight did not have sufficient controls to
    monitor the output from SMARS, such as **a control to compare orders leaving SMARS with
    those that entered it**." → the `ORDER_RATE_LIMIT` and parent/child sanity check.
  - **No self-halt (¶21).** "Knight also did not have procedures in place to **halt SMARS's
    operations in response to its own aberrant activity**." → `KILL_SWITCH_ACTIVE`.
  - **A price band that was too wide and did not apply everywhere (¶21).** Knight capped
    limit prices at 9.5% through the NBBO, "However, this control would not prevent the entry
    of erroneous orders in circumstances in which the National Best Bid or Offer moved by
    less than 9.5 percent. Further, it did not apply to orders … received before the market
    open." → `PRICE_BAND`: **a band that is too wide, or that has a gap in its coverage, is
    not a control.**
  - **Position limits that ignored working orders (¶22).** "Although Knight had position
    limits for some of its trading groups, **these limits did not account for the firm's
    exposure from outstanding orders**." → `MAX_POSITION` must be checked against
    position **+ working orders**, not position alone.
  - **Limits not wired to order entry (¶22–24).** Knight assigned a $2m gross limit to its
    "33 Account" "but it did not link this account to any automated controls concerning
    Knight's overall financial exposure," so "SMARS continued to send millions of child
    orders to the market." → `MAX_NOTIONAL` / `MAX_DAILY_LOSS` must **block**, not merely
    report.
  - **The monitoring tool was a dashboard, not a control (¶25).** PMON "is a
    **post-execution** position monitoring system … **PMON relied entirely on human
    monitoring and did not generate automated alerts** regarding the firm's financial
    exposure. PMON also did not display the limits for the accounts or trading groups; the
    person viewing PMON had to know the applicable limits to recognize that a limit had been
    exceeded. **PMON experienced delays during high volume events** … resulting in reports
    that were inaccurate." → **this is the sharpest lesson in the document.** A god-mode
    read-only panel that shows positions is *not* a risk control. CrashLab's own god-mode
    panel is explicitly read-only; make sure the actual enforcement lives in the pre-trade
    gate, and be ready to say so.
  - **Dead code left callable (¶13, and the finding at ¶9.D).** The SEC found Knight lacked
    "technology governance controls and supervisory procedures sufficient to ensure the
    orderly deployment of new code or **to prevent the activation of code no longer intended
    for use** … but left on its servers."

- **What the SEC charged (¶9).** Violations of Rule 15c3-5(c)(1)(ii) (erroneous orders),
  (c)(1)(i) (pre-set capital thresholds — "Knight failed to link accounts to firm-wide
  capital thresholds, and Knight relied on financial risk controls **that were not capable of
  preventing the entry of orders**"), (b) (written description; technology governance;
  incident-response procedures), (e)(1) (review) and (e)(2) (CEO certification). Settlement:
  $12 million.

- **Soutenance value:** if asked "why do you have ten pre-trade checks?", the strongest
  possible answer is a 45-minute, $460 million worked example in which each of your checks
  corresponds to a specific finding by a securities regulator.

### F2. SEC Rule 15c3-5, "Risk Management Controls for Brokers or Dealers with Market Access"

- 17 C.F.R. § 240.15c3-5. Adopting release: Exchange Act Release No. **34-63241**,
  75 Fed. Reg. 69792 (15 November 2010).
  Rule text: https://www.law.cornell.edu/cfr/text/17/240.15c3-5 (verified — Cornell LII, free)
  Adopting release PDF: https://www.sec.gov/files/rules/final/2010/34-63241.pdf
  (SEC.gov 403s automated fetchers; opens in a browser)
  Federal Register version:
  https://www.federalregister.gov/documents/2010/11/15/2010-28303/risk-management-controls-for-brokers-or-dealers-with-market-access
  Staff FAQ:
  https://www.sec.gov/rules-regulations/staff-guidance/trading-markets-frequently-asked-questions/divisionsmarketregfaq-0
  (**I could not fetch the FAQ — 403 — so I make no claims about its contents.**)
- **Free. ~1 hour** for the rule text; **~4 hours** if you read the adopting release, which is
  long but explains the *reasoning*.
- **Take from it — the rule text is remarkably close to CrashLab's ten checks.** Verified
  paragraph content from Cornell LII:
  - **(b)** — establish, document and maintain "a system of risk management controls and
    supervisory procedures reasonably designed to manage the financial, regulatory, and other
    risks of this business activity."
  - **(c)(1)(i)** — "Prevent the entry of orders that exceed appropriate **pre-set credit or
    capital thresholds** in the aggregate for each customer and the broker or dealer."
    → `MAX_NOTIONAL`, `MAX_LEVERAGE`, `MAX_DAILY_LOSS`, `INSUFFICIENT_MARGIN`.
  - **(c)(1)(ii)** — "**Prevent the entry of erroneous orders, by rejecting orders that
    exceed appropriate price or size parameters, on an order-by-order basis or over a short
    period of time, or that indicate duplicative orders.**"
    → this one sentence is `MAX_ORDER_SIZE` (size), `PRICE_BAND` (price),
    `ORDER_RATE_LIMIT` ("over a short period of time"), and the duplicate-order check.
  - **(c)(2)** — regulatory controls, including preventing unauthorised trading and
    restricting access to "persons and accounts pre-approved and authorized by the broker or
    dealer."
  - **(d)** — the controls must be **"under the direct and exclusive control of the broker or
    dealer."** → the architectural point for CrashLab: **the risk gate must not be
    implemented inside the agent.** An agent cannot be trusted to enforce limits on itself;
    the exchange-side gateway owns the checks. This is the design justification for putting
    all ten checks in the gateway/risk actor rather than in agent code.
  - **(e)** — regular review of effectiveness plus annual CEO certification.
- **Note the emphasis, from the adopting release title and the Knight order's ¶7:** the
  controls must be **pre-trade** and **automated**. A control that reports after the fact, or
  that requires a human to notice, is not compliant. That is the same lesson as PMON.

### F3. FIA, "Guide to the Development and Operation of Automated Trading Systems" (March 2015)

- Futures Industry Association, Market Technology Division, 23 March 2015.
  **https://www.fia.org/sites/default/files/2020-04/FIA%20Guide%20to%20the%20Development%20and%20Operation%20of%20Automated%20Trading%20Systems.pdf**
  (verified, HTTP 200, free)
  Announcement: https://www.fia.org/fia/articles/fia-issues-guide-development-and-operation-automated-trading-systems-0
- **Free. ~3 hours** for §1 alone; ~6 hours for the whole guide.
- **This is the best control-by-control reference on the list, and §1 maps almost
  one-to-one onto CrashLab's ten checks.** Verified §1 contents:

  | FIA §1 control | CrashLab check | What the guide says (verified) |
  |---|---|---|
  | **1.1 Maximum Order Size** | `MAX_ORDER_SIZE` | "commonly referred to as **'fat-finger' limits**." Must be applied "whenever a new order is submitted **or an existing order is modified**." Different limits per instrument type. **"Systems should be designed to prevent orders from being placed in cases where no order size limits have been set for an instrument"** — i.e. *fail closed on missing configuration*. |
  | **1.2 Maximum Intraday Position** | `MAX_POSITION` | "both current positions **and working orders** should be evaluated … It is important to include working orders such that limits would not be breached if that order is filled, even though it may not be immediately executable." (Exactly Knight's ¶22 failure.) Also: treat it as a **"speed-bump"** against accidental overtrading, backed by post-trade controls; and limits "should be set by the authorized person **independent of** the trader." |
  | **1.3 Market Data Reasonability** | `STALE_ORACLE` | Validate incoming market data on "**the time since the last update was received**, previous price, bid/offer spread, or deviation from an average price. If there appears to be a deviation … an alert should be provided that market data may be **stale**, and **any orders should be blocked** while the deviation is investigated." |
  | **1.4 Price Tolerance** | `PRICE_BAND` (firm side) | "the maximum amount an individual order's limit price may deviate from a reference price … applied **before the order is sent to the exchange**." |
  | **1.5 Repeated Automated Execution Limits** | `ORDER_RATE_LIMIT` (strategy side) | "the maximum number of times a strategy or identical order is filled and then **re-enters the market without human intervention**. After a configurable number of repeated executions, **the strategy should be disabled until an authorized person re-enables it**." (This is the control that would have stopped Knight.) |
  | **1.6 Exchange Dynamic Price Collar** | `PRICE_BAND` (venue side) | "also called **price banding** … the maximum amount a new trade price can deviate from a reference price such as the instrument's last trade price." Note the design tension the guide flags: "care should be taken that exchange-set price collars are **not too restrictive**." |
  | **1.7 Exchange Market Pauses** | (M7 cascade) | Velocity/stop logic that pauses trading when a stop cascade is detected. The guide's warning is worth quoting in the M7 report: a pause "may dramatically reduce a market participant's ability to manage risk," so the goal is "keeping markets open as much as possible" and preventing cascades with *upstream* controls instead. |
  | **1.9 Message Throttles** | `ORDER_RATE_LIMIT` | Message-rate limiting; the guide cautions against mandating universal throttles because appropriate rates differ by strategy and instrument. |
  | **1.10 Self-Match Prevention** | (not in the ten, but relevant) | Distinguishes **wash trades** (prohibited), **bona fide self-matches**, and **inadvertent self-matches**. With 200–1000 agents on one book you *will* generate inadvertent self-matches between agents under common control; decide your policy and document it. |
  | **1.11 Kill Switches** | `KILL_SWITCH_ACTIVE` | "immediately disables all trading activity for a particular participant or group … typically preventing the ability to enter new orders **and cancelling all working orders**. It **may also allow for risk-reducing orders while preventing risk-increasing orders**." Two design points to steal: (a) a kill switch is "a **last resort** when other actions have failed"— "In an environment that has adequate pre-trade risk controls at all appropriate focal points … a kill switch may ultimately be considered **redundant**"; (b) "the automated trader **should not be able to override a kill switch invoked by the broker**." → in CrashLab, the god-mode panel's global kill switch must not be overridable by an agent. |
  | **1.12 Cancel-On-Disconnect** | (subject: "se retirer lorsque … la connexion cross-exchange est perdue") | On loss of connectivity the venue cancels the session's resting orders; cancellation granularity should be **per session**, not per firm, so other sessions keep working. |

- **The "risk-reducing orders allowed while risk-increasing orders blocked" idea from 1.11 is
  worth implementing.** A kill switch that blocks *all* orders can trap an agent in a
  position it cannot exit. Distinguishing the two is a small amount of code and a very good
  soutenance answer.

### F4. FIA, "Best Practices for Automated Trading Risk Controls and System Safeguards" (July 2024)

- Futures Industry Association, July 2024.
  **https://www.fia.org/sites/default/files/2024-07/FIA_WP_AUTOMATED%20TRADING%20RISK%20CONTROLS_FINAL_0.pdf**
  (verified, HTTP 200, free)
- **Free. ~2 hours.**
- **Take from it:** the current-decade update of F3, consolidating FIA's earlier work
  (including its paper on Exchange Volatility Control Mechanisms). Verified TOC:
  §1 Pre-Trade Controls (1.1 Maximum Order Size, 1.2 Maximum Intraday Position,
  1.3 Price Tolerance, 1.4 Cancel-On-Disconnect, 1.5 Kill Switches, 1.6 Exchange-Provided
  Order Management); §2 Exchange Provided Volatility Control Mechanisms (2.1 Exchange Dynamic
  Price Collar, 2.2 Daily Price Limits, 2.3 Mechanisms to Interrupt Continuous Trading);
  §3 Other Tools and Controls (3.1 Market Data Responsibility, 3.2 Repeated Automated
  Execution Limits, 3.3 Exchange Message Programs, 3.4 Message Throttles, 3.5 Self-Match
  Prevention); §4 Post-Trade Analysis (4.1 Drop Copy Reconciliation, 4.2 Post-Trade Credit
  Controls, 4.3 Exchange Error Trade Policies); §5 Testing (5.1 Exchange-Based Conformance
  Testing).
- **The one line to internalise**, from §1's opening: **"Localized pre-trade risk controls,
  not credit controls, should be the primary tools used to prevent inadvertent market
  activity due to unauthorized access, system failures and errors."** Credit/margin checks
  (`INSUFFICIENT_MARGIN`, `MAX_LEVERAGE`) protect *solvency*; localized pre-trade checks
  (`MAX_ORDER_SIZE`, `PRICE_BAND`, `ORDER_RATE_LIMIT`) protect against *bugs*. They are
  different jobs. Knight was solvent and still lost $460m to a bug.
- **Read F3 for depth and F4 for currency.** F3's §1 is more detailed per control; F4 tells
  you which controls the industry still considers primary in 2024. Note that §4 "Post-Trade
  Analysis" also names **drop copy reconciliation**, which is the industry's name for
  exactly the M11 "Ledger — réconciliation à zéro écart" requirement.

### F5. MiFID II RTS 6 — Commission Delegated Regulation (EU) 2017/589

- Commission Delegated Regulation (EU) 2017/589 of 19 July 2016 supplementing Directive
  2014/65/EU with regard to regulatory technical standards specifying the organisational
  requirements of investment firms engaged in algorithmic trading.
  **https://eur-lex.europa.eu/eli/reg_del/2017/589/oj/eng** (free, official)
  HTML: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32017R0589
- **Free. ~2 hours** for Articles 12, 15, 16, 17.
- **Take from it — this is the *legally binding* version of F3/F4, and it is short:**
  - **Article 12, "Kill functionality"** — "An investment firm shall be able to cancel
    immediately, as an emergency measure, any or all of its unexecuted orders submitted to
    any or all trading venues to which the investment firm is connected." Note the mandate to
    identify which algorithm/trader/desk/client is responsible for each order — that is an
    *attribution* requirement, and CrashLab's event schema should carry the originating agent
    ID for exactly this reason.
  - **Article 15, "Pre-trade controls on order entry"** — enumerates, for all instruments:
    **price collars** (automatically block/cancel orders outside price parameters),
    **maximum order values**, **maximum order volumes**, and **maximum message limits**;
    plus automated execution throttles limiting strategy repetition, and market/credit risk
    limits based on capital and clearing arrangements. Article 15(5) covers automatic order
    cancellation.
  - **Article 16, "Real-time monitoring"** — monitoring during trading hours for disorderly
    trading, by the trader in charge or an independent risk-control function, with real-time
    alerts generated **within five seconds** of the relevant event.
  - **Article 17, "Post-trade controls"** — continuous exposure monitoring; **reconciliation
    of electronic trading logs against venue, broker and clearing records**; for derivatives,
    maximum long/short position limits.
  (All four articles read from the EUR-Lex HTML text.)
- **Why this is valuable for CrashLab specifically:** Article 15's four-item list is almost
  exactly `PRICE_BAND` + `MAX_NOTIONAL` + `MAX_ORDER_SIZE` + `ORDER_RATE_LIMIT`, and
  Article 16's *five-second* alerting deadline is a concrete, citable latency requirement
  you can point at when justifying why your risk actor must be fast.

### F6. Exchange-level controls: CME Group

- **CME Globex Market Integrity Controls (client systems wiki, free):**
  https://cmegroupclientsite.atlassian.net/wiki/spaces/EPICSANDBOX/pages/457216065/Market+Integrity+Controls
  — verified. Enumerates: **Messaging Controls** (prevent excessive messaging rates),
  **Limits and Banding** (price integrity), **Velocity Logic** (suspends a market when
  executions occur outside predefined price-movement thresholds within a timeframe),
  **Market and Instrument States**, **Automated Port Closure** (logs out and closes ports for
  sessions exceeding invalid-logon thresholds), **Protection Functionality for Market and
  Stop Orders** ("prevents Market and triggered Stop orders from being filled at extreme
  prices"), and Market Segment Gateway Safeguards.
- **CME Globex Messaging Controls:**
  https://cmegroupclientsite.atlassian.net/wiki/spaces/EPICSANDBOX/pages/457317540/Messaging+Controls
  — measured in transactions per second, enforced **at the iLink session level**, with
  distinct **Reject** and **Terminate** thresholds; CME automatically closes ports for
  sessions exceeding 200 administrative messages/second over a three-second window.
- **CME Globex Credit Controls (GC2) and Kill Switch:**
  https://www.cmegroup.com/tools-information/webhelp/globex-credit-controls/Content/CME-Globex-Credit-Controls-Management.html
  and the Risk Management Tools help home:
  https://www.cmegroup.com/tools-information/webhelp/globex-credit-controls/Content/Home.html
  — GC2 provides **pre-execution** exposure and maximum-quantity limits set by clearing-firm
  risk administrators, with configurable real-time actions on breach: **e-mail notification,
  order blocking, and order cancellation.**
  (CME's marketing page https://www.cmegroup.com/solutions/market-access/globex/trade-on-globex/pre-trade-risk-management.html
  **timed out on me** — I make no claims about its contents.)
- **Free. ~2 hours** across those pages.
- **Take from it:** a real venue's actual control surface, which is the model for what
  CrashLab's Exchange A and B should expose. Two design ideas worth stealing:
  1. **Three graduated responses on breach** (notify / block / cancel-all) rather than a
     single binary. Your ten checks can each declare which response they trigger.
  2. **Reject threshold and Terminate threshold as separate levels** for rate limiting —
     exceed the first and messages bounce; exceed the second and the session dies. That is a
     much better `ORDER_RATE_LIMIT` design than a single cutoff, and it is what a real
     exchange does.

### F7. SEC & CFTC staff, "Findings Regarding the Market Events of May 6, 2010"

- Report of the staffs of the CFTC and SEC to the Joint Advisory Committee on Emerging
  Regulatory Issues, **30 September 2010**.
  **https://www.cftc.gov/sites/default/files/idc/groups/public/@otherif/documents/ifdocs/staff-findings050610.pdf**
  (verified, HTTP 200, free)
  SEC copy: https://www.sec.gov/news/studies/2010/marketevents-report.pdf
- **Free. ~3 hours** (~100pp; the executive summary and the first two substantive sections
  carry most of the value).
- **Take from it:** the canonical worked example of a **liquidity-driven cascade** — a large
  automated sell program executed against thinning liquidity, liquidity providers withdrawing,
  cross-market propagation between the futures and equity markets, and stub quotes printing
  absurd prices. **This is M7's scenario with real data**, and it is the empirical
  justification for `PRICE_BAND`, for market pauses, and for CrashLab's design decision that
  B stays anchored to the oracle while A uses its local last price.
- **Caveat: I did not read this report during this research pass** — I verified only its
  title, date, authorship and that the PDF is live. The characterisation above reflects the
  report's well-established subject matter, not verified quotations. **Do not quote specific
  figures from it without reading it.**

### F8. Oracle risk: Chainlink documentation, and the Mango Markets enforcement action

Two sources for `STALE_ORACLE` and for why the subject insists B stays oracle-anchored.

**F8a. Chainlink Data Feeds documentation — "Check the timestamp of the latest answer"**
- https://docs.chain.link/data-feeds — section anchor
  https://dev.chain.link/data-feeds#check-the-timestamp-of-the-latest-answer (verified)
- **Free. ~45 minutes.**
- **Take from it:** the two-parameter update model — a feed updates when the price moves
  beyond a **deviation threshold** *or* when a **heartbeat** interval elapses, whichever comes
  first; the heartbeat exists so consumers "are not left relying on an old value
  indefinitely." Consumers must check `updatedAt` from `latestRoundData()` against a staleness
  threshold that "should correspond to the heartbeat of the oracle's price feed," and on
  detecting staleness should **"pause operation or switch to an alternate operation mode."**
- **This gives `STALE_ORACLE` a precise specification** rather than a vibe: the threshold is
  derived from the feed's own heartbeat, and the response is *pause / degraded mode*, not
  *ignore*. It also names the design (deviation + heartbeat) you should implement in
  CrashLab's oracle so that "stale" is a well-defined state rather than an accident.

**F8b. CFTC v. Avraham Eisenberg (Mango Markets), filed 9 January 2023**
- CFTC Press Release 8647-23: https://www.cftc.gov/PressRoom/PressReleases/8647-23
- **Free. ~30 minutes** for the press release; longer for the complaint.
- **Take from it:** the CFTC's first enforcement action for "oracle manipulation." Per the
  CFTC's own account: on **11 October 2022** the defendant opened large leveraged positions
  in a swap whose value derived from the MNGO price, then bought MNGO aggressively on the
  three exchanges that fed the oracle, driving the price up more than **13-fold in about 30
  minutes**, inflating his positions' mark value and allowing withdrawal of over **$110
  million**.
- **Why it is on this list:** it is the incident behind CrashLab's entire A/B architecture.
  A mark price derived from a thin, manipulable local source is an attack surface. This is
  soutenance Q1 ("why must Binance's price not be injected directly into the local book?")
  and Q2 ("why must local last price and mark price not always be identical?") answered with
  a real enforcement action and a real $110m number.
- **Caveat:** figures above are from the CFTC press release as summarised in search results;
  **I did not fetch the press release or the complaint directly.** Verify before quoting.

---

## 7. Implement M8 vs. defend M8

### 7a. Minimum to *implement* M8 and the M7 metrics

Roughly **25–30 hours** of reading, and the majority is free.

| # | Source | Free? | Time |
|---|---|---|---|
| B1 | BCBS FRTB explanatory note (ES vs VaR) | Free | 45 min |
| B2 | Hull *RMFI* **Ch. 13** (historical simulation algorithm) | Paid | 3 h |
| B3 | RiskMetrics **Ch. 6 §6.3** (computing VaR) | Free | 2 h |
| C5 | The netting method above, cross-checked against B2/B3 | — | — |
| B7 | Danielsson code companion (as a test oracle) | Free | 2 h |
| A3 | ITG implementation-shortfall article | Free | 45 min |
| A6 | Kissell **Ch. 3** (shortfall decomposition with partial fills and fees) | Paid | 3 h |
| D1 | Magdon-Ismail & Atiya, maximum drawdown | Free | 1.5 h |
| D2 | Hull *OFOD* **Ch. 19** (delta; delta-hedging for M9) | Paid | 4 h |
| F3 | FIA Guide **§1** (the ten controls, control by control) | Free | 3 h |
| F2 | SEC Rule 15c3-5 text (Cornell LII) | Free | 1 h |
| E1 | Gil Tene, "How NOT to Measure Latency" | Free | 1 h |
| E2 | Coordinated omission post | Free | 45 min |
| E3 | HdrHistogram + HdrHistogram_c READMEs | Free | 2 h |
| E9 | Google Benchmark user guide | Free | 1 h |

### 7b. Additional reading to *defend* M8 at the soutenance

**~20 hours, almost entirely free.** This is where the marks are: the subject says explicitly
that gross PnL is not enough and that the team must answer *without reading its code*.

| # | Source | Defends | Free? | Time |
|---|---|---|---|---|
| **C1** | **BCBS WP19 §3 and §5** | **Q8** — the whole netting argument, from a regulator | Free | 3 h |
| **C2** | **RiskMetrics §3.1 + Chart 3.1, and §3.4.1** | **Q8** — hierarchical limits; a regulator that got it wrong | Free | 30 min |
| C3 | Embrechts, McNeil & Straumann | Q8 — why the correlation "fix" has its own hidden assumption | Free | 3 h |
| B5 | Artzner et al., coherence axioms | Q8 — the formal property | Paid* | 3 h |
| B6 | Acerbi & Tasche | the ES bonus; discrete-distribution correctness | Free | 2 h |
| **B4** | **BCBS backtesting framework (1996)** | "how do you know your VaR is right?" | Free | 1.5 h |
| **F1** | **SEC Knight Capital order** | "why ten controls?" and Q10 (fragile assumptions) | Free | 2 h |
| F5 | MiFID II RTS 6 Arts. 12, 15, 16, 17 | the legally-binding control list | Free | 2 h |
| F4 | FIA 2024 best practices | current industry position; drop-copy reconciliation | Free | 2 h |
| F6 | CME Globex control docs | what a real venue actually enforces | Free | 2 h |
| **E4** | **Dean & Barroso, "The Tail at Scale"** | **Q7** — fan-out amplification | Free | 1.5 h |
| E5 | "Why Percentiles Don't Work the Way You Think" | Q7 — don't average percentiles | Free | 20 min |
| E7 | Ousterhout, "Always Measure One Level Deeper" | **Q9** — measured, not assumed | Free | 1 h |
| E8 | Georges et al., statistically rigorous evaluation | Q9 — before/after with confidence intervals | Free | 2 h |
| E6 | Gregg, *Systems Performance* Ch. 2 & 12 | general benchmarking discipline | Paid | 5 h |
| A2 | Perold 1988 | naming the origin of the slippage formula | Paid | 1 h |
| F7 | Flash Crash report | M7 cascade grounding | Free | 3 h |
| F8b | CFTC Mango Markets action | Q1, Q2 — oracle manipulation | Free | 30 min |

\* author copy on ResearchGate.

**Total cost if you buy the four paid books** (Harris, Hull ×2, Kissell, Gregg): roughly
€350–450 new; substantially less second-hand or through a library. **If you buy only two:
Hull *RMFI* and Kissell.**

---

## 8. The two questions, answerable cold

### "Why is an average latency insufficient?" (soutenance Q7)

Sources: **E1** (primary), **E4**, **E2**, **E5**.

Four independent reasons, in increasing order of force:

1. **The distribution is multi-modal** (E1). Latency comes from qualitatively distinct code
   paths — the fast path, the contended path, the stalled path. The mean falls in a *valley
   between* the modes. It reports a value that essentially never occurs, and it moves in
   ways that do not correspond to anything anyone experiences. Standard deviation is
   meaningless for the same reason: it presumes one mode.
2. **The mean is dominated by the common case; the tail is what actually gets experienced**
   (E4). With fan-out across *k* components, the probability that a request escapes *all* of
   them quickly is `p_fast^k`. Dean & Barroso's arithmetic: 100 components each slow 1% of
   the time yields ~63% of requests being slow. In CrashLab, `agent decision → fill
   end-to-end` traverses gateway, matching, publication and position update; its p99.9 is
   determined by the *union* of the components' tails, not by any component's mean. This is
   why the subject asks for the metric on five stages *and* end-to-end.
3. **The mean cannot be reconstructed into a tail, and tails cannot be averaged** (E5). Given
   a mean you cannot recover p99.9. And given per-run p99.9s you cannot average them into a
   window p99.9 — a percentile is a position statistic requiring the underlying population.
   Only the full distribution (a histogram) supports both, which is why the subject demands
   `count, min, mean, p50, p95, p99, p99.9, max` — the full shape — rather than one number.
4. **Naive harnesses under-report the tail by orders of magnitude anyway** (E2). Under
   coordinated omission, a benchmark that waits for each response before issuing the next
   silently deletes precisely the samples generated during stalls. Tene reports 99.99th
   percentiles understated by up to ~35,000×. So the mean is not merely uninformative — in a
   naive harness *even the percentiles are wrong*, and they are wrong in the flattering
   direction, which is the worst possible failure mode for a measurement.

**Additional credit:** distinguish **service time** from **response time**, explain that your
harness drives load from a fixed intended schedule and timestamps against intended send time,
and state that you use HdrHistogram's coordinated-omission-correcting record function
(`hdr_record_corrected_value`).

### "How did you aggregate VaR across A and B?" (soutenance Q8)

Sources: **C1** (primary), **C2**, **C5**, **C3**, **B5**.

**The one-line answer:** *We did not aggregate VaR numbers. We aggregated **positions** into
a single net exposure to the shared risk factor, built one P&L series for the combined
portfolio by applying each recorded oracle return to that net exposure, and took a single
99% quantile of that series. `VaR_A + VaR_B` is published alongside it only as the naive
baseline the subject asks for, and the difference between them is the diversification
benefit.*

**Why the naive sum is wrong, in four escalating layers:**

1. **The mechanical reason.** The quantile operator is not additive: `Q(X+Y) ≠ Q(X) + Q(Y)`.
   Adding `VaR_A` and `VaR_B` takes each quantile *first* and adds *after*, which implicitly
   asserts that A's worst day and B's worst day are the same day, in the same direction.
   When the positions hedge, A's worst day *is* B's best day — the assertion is not merely
   imprecise, it is inverted. Netting first and taking the quantile once lets the positions
   cancel *inside each scenario*, before the quantile is taken.
2. **The institutional reason** (C2). This is a documented real-world error, not a
   pedagogical one. The RiskMetrics Technical Document (1996) §3.4.1 says of the European
   Capital Adequacy Directive that it "computes the capital requirement as a sum of capital
   requirements on positions of different types in different markets. It does not take into
   account the risk reducing effect of diversification," which "will lead financial
   institutions … to overestimate their market risks." A legislative directive did exactly
   this. Conversely §3.1 and Chart 3.1 show the intended structure: a hierarchical limit
   scheme in which "the risk limit at higher levels can be **lower** than the sum of risk
   limits of units reporting to it."
3. **The theoretical reason** (B5, C1). Subadditivity — `R(L1+L2) ≤ R(L1)+R(L2)` — is one of
   Artzner et al.'s four coherence axioms, and per BCBS WP19 it is the property that
   "makes decentralisation of risk-management systems possible": without it you cannot
   delegate a risk budget to desks. VaR satisfies the other three axioms and can violate
   this one. Expected Shortfall does not.
4. **The reason it is worse than "you forgot correlation"** (C1 §5.2, C3). BCBS WP19 states
   that summing compartmentalised VaR is conservative only when the books' risks are genuinely
   distinct; when "the separation is due only to accounting rules" — which is exactly what A
   and B are, one underlying split by venue — the sum "may **understate** the risk of the
   combined portfolio risk," and "In general, it will not be" conservative. So naive addition
   can err in *either* direction. And the obvious repair,
   `sqrt(VaR_A² + VaR_B² + 2ρ·VaR_A·VaR_B)`, silently assumes an elliptical joint
   distribution (C3; WP19 cites McNeil et al. Thm 6.8 for VaR's subadditivity under
   ellipticality) — an assumption M7's cascade scenario is specifically designed to break.
   That is why we net at the position level and revalue, rather than combining VaR numbers
   with a correlation.

**Additional credit:** note that BCBS WP19 reports 99% VaR being *superadditive* for tail
indices above 6 (Degen, Embrechts & Lambrigger 2007), which the paper calls "realistic cases
in market risk" — so the subadditivity failure is not a pathological textbook construction;
and mention that you also publish 97.5% Expected Shortfall, which is coherent, and that this
is the same substitution the Basel Committee made in the FRTB for the same reason (B1).

---

## 9. Things I could not verify — do not treat these as confirmed

Listed plainly, per the ticket's instruction.

1. **Harris, *Trading and Exchanges*, Ch. 21 title.** "Liquidity and Transaction Cost
   Measurement" comes from secondary summaries; the OUP contents page returned nothing
   usable. Chapter number is high-confidence, exact title is medium-confidence.
2. **Almgren & Chriss free PDF.** `https://www.cims.nyu.edu/~almgren/papers/optliq.pdf` is
   the commonly cited location; it returned **HTTP 403** to me. I do not know whether it is
   gone or merely blocking automated clients.
3. **Hull *RMFI* section numbers within Ch. 12/13** (e.g. "12.4 Expected Shortfall",
   "12.5 Coherent Risk Measures"). These come from a 4th-edition TOC seen in search results.
   Chapter *titles* for the 5th edition are confirmed; **section numbers are not** and differ
   between editions.
4. **SEC staff FAQ on Rule 15c3-5.** URL recorded, **content not read** (403). No claims made
   about it.
5. **Federal Register / eCFR full text of 15c3-5.** Both redirect automated clients to an
   "unblock" page. I used Cornell LII, which is a faithful reproduction but is not the
   government's own server. If precision matters, read the SEC PDF in a browser.
6. **The Flash Crash report (F7).** Verified as live with correct title, date and authors;
   **I did not read it.** The characterisation of its findings is general knowledge, not a
   verified quotation. Do not cite figures from it unread.
7. **CFTC Mango Markets figures (F8b).** From the CFTC press release *as summarised in search
   results*; I did not fetch the release or the complaint. Verify the 13-fold/30-minute/$110m
   figures before using them.
8. **Joint Forum "Developments in Modelling Risk Aggregation" (C4).** Findings read from the
   BIS landing page and press release, not the PDF body.
9. **BCBS d457 (the FRTB standard itself) and MAR33.** I verified the standard's title/date/URL
   and I verified the 97.5% ES figure **only from the explanatory note (d457_note.pdf)**, not
   from the standard's own paragraph text. The Basel Framework chapter pages
   (bis.org/basel_framework/chapter/MAR/33.htm) returned only navigation chrome to me. Do not
   cite a MAR paragraph number without opening it.
10. **Bakhvalov's book chapter titles/numbers (E10).** Repository, licence and free-PDF
    availability verified; chapter structure **not** verified.
11. **`pytest-benchmark`** for the Python side of M11 — named but not researched.
12. **Inventory-risk sources (D3)** — Ho & Stoll, Avellaneda & Stoikov named from memory,
    **no URLs or editions verified**. Cross-check with issue 03's list.
13. **CME "Pre-Trade Risk Management" marketing page** — timed out; no claims made. The wiki
    pages in F6 *were* verified.
14. **Ousterhout PDF mirror** at `rcs.uwaterloo.ca` — did not respond to my check. The CACM
    open-access page is the reliable route.
15. **Artzner et al. free copy** — the ResearchGate author-upload URL was found in search
    results; I did not open it and cannot confirm the file is the full paper.
16. **ITG/Mittal article publication venue and date.** The free UPenn mirror is verified live
    and its content is quoted accurately above, but I could not establish the original
    publisher, issue or date. Cite it as an ITG trade-press article of unknown date, or find
    the original before citing it formally.
