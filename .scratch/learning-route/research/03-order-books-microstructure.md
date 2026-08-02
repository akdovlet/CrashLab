# Reading list: order books and market microstructure

Resolves issue `03-reading-order-books-microstructure.md`.

**Reader assumed:** strong programmer, fluent C++98, zero finance. Every item below is
pitched at that person and ordered so each one is comprehensible given the ones before it.

**Total prerequisite load before writing M2's matching engine: roughly 30–40 hours of
reading**, of which about 12 hours are the one book you have to buy. Everything else in
the prerequisite tier is free and downloadable.

---

## How this list is organised

Six stages. Stages A–D are the **M2 prerequisite path**. Stage E is the economics that
makes M6 (market maker) and M7 (cascade) intelligible and is **deferrable until after M2
compiles**. Stage F is the "four prices" thread, which is short and should be read early
even though you only implement it in M4.

A running note: this project's pedagogical payload is the distinction between
**reference price / local mid / local last traded price / mark price**. No single source
teaches all four together, because in equity microstructure (Harris, Foucault, Bouchaud)
there is no mark price at all — mark price is a derivatives-clearing concept. So the four
prices are assembled from two literatures: stages A–E give you mid/last/spread rigorously,
stage F gives you index and mark from the exchanges that invented them. Do not expect a
textbook to hand you the whole quartet.

---

## Stage A — the mechanism and its vocabulary

### A1. Harris, *Trading and Exchanges: Market Microstructure for Practitioners* — Ch. 2, 3, 4, 6

> Larry Harris, *Trading and Exchanges: Market Microstructure for Practitioners*, Oxford
> University Press, 2003. ISBN 0-19-514470-8 / 978-0-19-514470-3. 643 pp.
> Publisher page: https://global.oup.com/academic/product/trading-and-exchanges-9780195144703

**Status: MUST BUY.** This is the one purchase on the list and it is not optional. There
is no free equivalent that covers order properties at this level of concreteness.

Read, in this order:

| Chapter | Title | What to take from it |
|---|---|---|
| 2 | Trading Stories | Narrative scene-setting. Skim in one sitting. Its only job is to give you the cast of characters (dealers, brokers, informed traders, value traders) so the later chapters aren't abstract. |
| 3 | The Trading Industry | Who the participants are and what they want. Skim. You need it to know *why* CrashLab's agent families (noise / mean-reversion / momentum / market maker) are the canonical taxonomy and not an arbitrary invention. |
| 4 | Orders and Order Properties | **The core chapter for M2.** What an order *is*; bid/offer, best bid, best offer, BBO, bid/ask spread, size; the difference between *offering* liquidity and *taking* it (this is exactly maker vs taker); why standing orders exist; market orders, limit orders, and the price/quantity/time conditions that hang off them. Harris is explicit that identical order instructions have different *properties* depending on the market they are sent to — that distinction is what makes your Exchange A and Exchange B comparable in the first place. |
| 6 | Order-driven Markets | **The other core chapter for M2.** §6.1.1 gives you *order precedence rules* and *trade pricing rules* as separate concepts — this separation is the single most useful abstraction for writing a matching engine, because it tells you the "who trades" decision and the "at what price" decision are independent. §6.1.1.1 price priority, §6.1.1.2 time precedence, plus the argument for *why* time precedence exists (it makes aggressive price improvement the only way to jump the queue, so it manufactures price competition) and the observation that time precedence is only meaningful if the tick size is not trivially small. That last point is a direct design constraint on your `tick_size` config. |

Chapter 5 (Market Structures) is worth a skim if you want the taxonomy of call auctions vs
continuous auctions vs dealer markets; it is not required for M2.

**Time:** Ch. 2+3 skim ≈ 2 h. Ch. 4 careful ≈ 4 h. Ch. 6 careful ≈ 4 h. Call it 10–12 h.

**Free sampler before you buy:** a March 2002 draft PDF is hosted openly on a University at
Buffalo course page:
https://www.acsu.buffalo.edu/~keechung/MGF743/Readings/Trading-Exchanges-Market-Microstructure-Practitioners%20Draft%20Copy.pdf
I downloaded and checked it: it is **front matter plus the opening few pages of each
chapter only** (≈6 000 lines of text for a 643-page book). It contains all of §4.1–4.3 and
§6.1–6.1.1.2, which is genuinely enough to confirm the book's register and to read the
price-priority / time-precedence sections. It is not a substitute for the book, and it is
Oxford-copyright material on a professor's course page — treat it as a preview.

### A2. Gould, Porter, Williams, McDonald, Fenn & Howison, "Limit Order Books" — §II and §III.D

> M. D. Gould, M. A. Porter, S. Williams, M. McDonald, D. J. Fenn, S. D. Howison,
> "Limit order books", *Quantitative Finance* 13(11):1709–1742, 2013.
> **Free preprint (identical content, 42 pp):** https://arxiv.org/abs/1012.0349
> (direct PDF: https://arxiv.org/pdf/1012.0349)

**Status: FREE.**

Read Harris first, then this. Harris gives you the words; Gould et al. give you the
formalism, and a programmer will find the formalism easier to hold in their head.

- **§II "A Mathematical Description of an LOB"** — §II.A Preliminaries (tick size, lot
  size, the state $\mathcal{L}(t)$), §II.B "Orders: the building blocks of an LOB" (an
  order as a tuple, active vs executed, the residual), §II.C "Price changes in LOBs"
  (bid $b(t)$, ask $a(t)$, mid, spread, and precisely *when* each can move — this is the
  formal statement of the subject's rule that "le local last price ne peut évoluer que par
  un trade local"), §II.D the economic benefits of LOBs.
- **§III.D "Priority"** — the best two pages anywhere on the ticket's question "why does
  time priority exist, and what does pro-rata change". Verbatim payload: price-time is by
  far the most common mechanism and "without a priority mechanism based on time, there is
  no incentive for traders to show their hand by submitting limit orders earlier than is
  absolutely necessary"; under pro-rata "traders … are faced with the substantial
  difficulty of optimally selecting limit order sizes, because posting limit orders with
  larger sizes than the quantity that is really desired for trade becomes a viable strategy
  to gain priority"; and a third mechanism, price-size, exists (NASDAQ OMX PSX, 2010). It
  also gives a worked pro-rata allocation example (a size-3σ market order splitting 1/3 :
  2/3 across two resting orders).
- **§III.E "Incomplete sampling and hidden liquidity"** — read this too; it is why your
  published L2 book is not the same object as your internal book.

Skip §IV and §V for now (empirical stylised facts and models) — they come back in the
deferrable tier for M5/M7.

**Time:** §II + §III.D + §III.E ≈ 3 h.

---

## Stage B — real rulebooks, and where they disagree

This is the stage the ticket flagged as "where the learning is". Three major venues
implement three genuinely incompatible answers to "who gets filled at the same price?".
Read all three; the contrast is the point. Total ≈ 3 h.

### B1. Nasdaq Equity 4, Rules 4702 / 4703 / 4757 — price / **display** / time

> Nasdaq Stock Market LLC rulebook, Equity 4.
> https://listingcenter.nasdaq.com/rulebook/nasdaq/rules/Nasdaq%20Equity%204
> Rule 4702 (Order Types), Rule 4703 (Order Attributes), Rule 4757 (Book Processing).

**Status: FREE.** Caveat I must flag: the Listing Center serves 403 to automated fetchers,
so I verified the rule numbers and the content of 4757 and 4703 through search snippets and
SEC rule-filing exhibits (e.g. https://www.sec.gov/files/rules/sro/nasdaq/2015/34-74558-ex5.pdf),
not by reading the live rulebook page myself. The page is reported to load normally in a
browser. If it does not, the SEC filing exhibits carry the same rule text.

What to take: Nasdaq's execution algorithm is **price / display / time**, not price / time.
Better-priced orders first; then, among equally-priced orders, *displayed* ones rank in time
priority ahead of non-displayed ones and the non-displayed portion of reserve orders. That
third key is the thing to notice — real exchanges routinely have a priority dimension your
mental model doesn't. Rule 4703 gives you time-in-force as a first-class *order attribute*
with an explicit activation time and an explicit expiry, which is a better model than
treating TIF as an enum.

CrashLab does not need display/non-display. You need to have *seen* it, so that when you
write `price then time` in your comparator you know you are choosing, not defaulting.

### B2. CME Globex Matching Algorithms — FIFO, Pro Rata, TOP, Leveling, Split

> CME Group Client Systems Wiki, "CME Globex Matching Algorithms" and
> "CME Globex Matching Algorithm Steps".
> https://cmegroupclientsite.atlassian.net/wiki/spaces/EPICSANDBOX/pages/457218521
> Overview page: https://cmegroupclientsite.atlassian.net/wiki/display/EPICSANDBOX/CME+Globex+Matching+Algorithms

**Status: FREE, partially gated.** The page returns HTTP 200 anonymously but itself warns
"You're viewing this with anonymous access, so some content might be blocked" — I could see
the section structure and the presence of "FIFO Example 1", "FIFO Example 2" and "Pro Rata
Example" tables, but cannot promise every worked example renders without a CME account.

What to take — the decomposition of a match into **ordered steps**, which is the single most
transferable idea here for M2's implementation:

1. **TOP** (Top Order) — a designated first-in-at-a-new-price order gets an allocation before
   anyone else.
2. **LMM** — a designated market maker gets a contracted percentage.
3. **Split FIFO/Pro-Rata** — a configured percentage of the incoming quantity is allocated
   FIFO, the rest pro-rata; the two percentages always sum to 100 %.
4. **Pro Rata** — each resting order's share is `floor(incoming × order_qty / total_qty_at_price)`,
   with a **Pro Rata Minimum** parameter below which an order gets nothing at all.
5. **Leveling** — distributes the lots lost to rounding down in step 4; no order gets more
   than one lot in this step.

Two things follow directly for CrashLab. First, `floor()` in step 4 means pro-rata **does not
conserve quantity by itself** — you need a documented tie-break for the remainder, which is
what Leveling is. If you ever implement pro-rata as a config option, that is the bug you will
have. Second, CME documents "Order Modification Loss of Timestamp Priority with FIFO":
modifying a resting order can cost it its queue position. That is exactly the semantics you
must decide for your `ReplaceOrder` event, and it is the reason cancel/replace is a separate
message rather than sugar over cancel-then-new.

### B3. Eurex T7 — time, pro-rata, and time-pro-rata

> Eurex, "Matching principles".
> https://www.eurex.com/ex-en/trade/order-book-trading/matching-principles

**Status: FREE.** Short — I fetched it and it is roughly one page of substantive content,
with no worked numeric examples (contrary to what secondary write-ups imply). Read it anyway:
it takes 15 minutes and it introduces a scheme neither Nasdaq nor CME uses.

What to take: **time-pro-rata**, an explicit interpolation between the two extremes — orders
with higher time priority get more than pure pro-rata would give them and less than pure time
allocation would. Also note Eurex's statement that pro-rata sorts book orders by *size*
first (largest first), with time priority only as a tie-break among equal sizes. That is
a different pro-rata from CME's percentage formula. Two major venues, both calling it
"pro-rata", allocating differently.

For deeper T7 detail (order types, order states, quote handling) the free
*T7 Functional Reference* and *T7 Functional and Interface Overview* PDFs are linked from
eurex.com — e.g. https://www.eurex.com/resource/blob/248102/87dfd8b551a1b0ee5a55a9c7de0106f5/data/Functional%20Reference.pdf
(v4.0.2, 2016 — old, but the order-state material is stable). Deferrable.

### B4. A crypto perp venue, for the rules you are actually cloning

> Deribit exchange documentation and rulebook.
> Order-management guide: https://docs.deribit.com/articles/order-management-best-practices
> Rulebook entry point: https://support.deribit.com/hc/en-us/articles/25944555524125-Deribit-Exchange-Rulebook

**Status: FREE.**

What to take: crypto perpetual venues are overwhelmingly **pure price-time**, which is the
rule CrashLab mandates ("Priorité prix puis temps"), plus two order flags you should
understand even if you don't implement them: **post-only** (never take; if the order would
cross, it is repriced one tick away from the best rather than executing — note it is
*repriced*, not rejected, which is a design decision you could have made either way) and
**reduce-only** (may shrink a position, never grow one — directly relevant to M4/M8's
liquidation and pre-trade-check work).

**The disagreement summary**, which belongs in your soutenance notes:

| Venue | Same-price allocation | Notes |
|---|---|---|
| Nasdaq equities | price → **display** → time | Rule 4757; non-displayed liquidity ranks behind displayed |
| CME Globex | configurable per product: FIFO, Pro Rata, Split, with TOP/LMM/Leveling steps | rounding-down means a remainder step is mandatory |
| Eurex T7 | time, pro-rata (size-sorted), or time-pro-rata | pro-rata semantics differ from CME's |
| Deribit / most crypto perps | price → time | plus post-only / reduce-only flags |

There is no "correct" answer. Price-time is the one CrashLab specifies; you should be able
to say in the soutenance *why* — it is the only one of the four that requires no per-order
metadata beyond a monotone sequence number, which is what makes deterministic replay
(M0's acceptance criterion) cheap.

---

## Stage C — order lifecycle, the mandated state machine, and idempotency

The subject mandates `CREATED → PENDING_NEW → LIVE → PARTIALLY_FILLED → FILLED`,
`PENDING_NEW → REJECTED`, `LIVE → PENDING_CANCEL → CANCELLED`. That is not an invention:
it is FIX's `OrdStatus` set with the names lightly changed. Reading the primary source is
how you stop copying it and start understanding it.

### C1. FIX 4.4, Appendix D — Order State Change Matrices

> FIX Protocol Ltd., *FIX 4.4 Specification*, Volume 4, Appendix D "Order State Change
> Matrices" (with June 2003 errata).
> **Freely readable HTML rendering:** https://www.onixs.biz/fix-dictionary/4.4/app_d.html
> Official (registration-walled) source: https://www.fixtrading.org/standards/fix-4-4/
> Field references: `OrdStatus` tag 39 — https://fiximate.fixtrading.org/legacy/en/FIX.4.4/tag39.html

**Status: FREE to read** via the Onix Solutions FIX Dictionary, which is a faithful HTML
rendering of the appendix. The zip of the seven official volumes from fixtrading.org is
also free but requires an account.

I verified Appendix D's contents. It contains twelve scenario groups —
A. Vanilla orders, B. Cancel requests, C. Cancel/Replace quantity changes,
D. Cancel/Replace sequencing and chaining, E. Unsolicited/Reinstatement, F. Order Reject,
G. Status requests, H. GTC orders, I. TimeInForce variations, J. Execution Cancels/Corrects,
K. Trading Halt, L. Miscellaneous — and the status set it uses is
**PendingNew, New, PartiallyFilled, Filled, DoneForDay, PendingCancel, PendingReplace,
Canceled, Rejected, Stopped**. It also assigns each status a *precedence* number, used to
decide which status wins when reports arrive out of order.

What to take, in order of importance to CrashLab:

1. **Why `PENDING_NEW` exists at all.** It is the state of an order the client has sent and
   the exchange has not yet acknowledged. It exists because the *client's* view and the
   *exchange's* view are two different state machines connected by a lossy link. If your
   gateway and matching engine are separate Simplx actors — and M2 says they are — you have
   exactly that split, and PENDING_NEW is the honest name for "in flight between actors".
2. **Why `PENDING_CANCEL` exists.** A cancel request is a *request*. Between request and
   acknowledgement the order is still live and can still fill. Appendix D section B walks
   the case where a fill and a cancel-ack race. This is the source of the invariant
   "un ordre CANCELLED ne peut plus être exécuté" — the invariant is only meaningful because
   there is a window in which the answer is genuinely uncertain.
3. **Cancel/replace as its own protocol** (sections C and D). Replace is not
   cancel-then-new: it has its own pending state, its own rejection path, and defined
   behaviour when replaces are chained or when a fill lands mid-replace. Section C's
   quantity-change cases are the exact arithmetic you need for "conservation du reliquat".
4. **The precedence numbers.** They are a ready-made rule for reconciling out-of-order
   execution reports — useful directly for M0's append-only journal.

**Time:** 3–4 h to read sections A–D carefully; skim E–L.

### C2. Nasdaq OUCH 5.0 Order Entry Specification

> Nasdaq, *OUCH 5.0 Order Entry Specification*, 25 pp.
> https://nasdaqtrader.com/content/technicalsupport/specifications/TradingProducts/Ouch5.0.pdf

**Status: FREE.** I downloaded and read this one; the quotations below are verbatim.

FIX tells you what the states are. OUCH shows you what a real, fast, binary order-entry
protocol actually ships — and it is startlingly close to the message set CrashLab's
Annexe A mandates.

Inbound (client → exchange): `O` Enter Order, `U` Replace Order Request, `X` Cancel Order
Request, `M` Modify Order Request, `C` Mass Cancel Request, `D` Disable Order Entry.
Outbound: `A` Order Accepted, `U` Order Replaced, `C` Order Canceled, `E` Order Executed,
`J` Rejected, **`P` Cancel Pending**, `I` Cancel Reject, **`T` Order Priority Update**,
`M` Order Modified, `R` Order Restated.

Four things to take:

1. **`P` Cancel Pending is a wire message.** Your `PENDING_CANCEL` state is not a modelling
   nicety; production exchanges emit it.
2. **`T` Order Priority Update** — "sent whenever priority of the order has been changed by
   the system". Queue position is a first-class, observable, mutable property. This closes
   the loop with CME's "modification loss of timestamp priority": priority is something the
   exchange owns and must *tell you about*.
3. **§2.2 Replace Order Request** — replace carries *two* client order references (the one
   being replaced and a fresh one), replaces may be chained arbitrarily, and the spec spells
   out the shares arithmetic when the original is partially filled: to keep the remaining 400
   of a 500-share order plus 100 more, you send a replace for 500, not 600. Read this before
   you design `ReplaceOrder`.
4. **§1.2 and §2 — idempotency. This is soutenance question 3.** Verbatim: "all host-bound
   messages are designed so that they can be benignly resent for robust recovery from
   connection and application failures"; "every order entered on OUCH is uniquely identified
   by the combination of the logical OUCH Account and the participant-created UserRefNum
   field"; the UserRefNum "must be both unique and strictly increasing throughout the trading
   day … the system ignores new order requests identified with UserRefNums lower than the
   last one processed, assuming they are retransmissions." That is the whole answer to "how
   do you prevent a double fill after a retry", and it is a monotone per-session counter plus
   a high-water mark — cheap enough for your critical path, and it composes with M0's
   requirement of a single global id per order.

**Time:** 2–3 h, reading §1, §2.1–2.3, §3.1–3.13.

---

## Stage D — how books are published: L2, L3, snapshots and incrementals

The subject requires "Publication L2, trades et snapshots cohérents" (M2) and a `GET /book`
plus `WS /stream` on Exchange B (M3). These three documents are the primary sources on how
that is actually done, and they disagree in instructive ways.

### D1. Nasdaq TotalView-ITCH 5.0 — an order-by-order (L3) feed

> Nasdaq, *Nasdaq TotalView-ITCH 5.0*, 36 pp, revision Feb 2024.
> https://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHSpecification.pdf

**Status: FREE.** Verified: 36 pages, current.

Read §1.3 (Add Order, pp. 12–13), §1.4 (Modify Order Messages: Order Executed, Order
Executed With Price, Order Cancel, Order Delete, Order Replace, pp. 14–15), §1.5 (Trade
Messages, pp. 16–18). Skip the rest.

What to take:

- ITCH publishes **individual orders**, not aggregated price levels. A subscriber
  reconstructs the book by replaying adds, executes, cancels and deletes. This is the L3
  feed. Your L2 publication is a *projection* of this — knowing that makes it obvious why
  your `MarketDataPublisherActor` should derive L2 from the book rather than maintain a
  parallel one.
- The distinction between **Order Cancel** (partial reduction) and **Order Delete** (full
  removal) — two messages for what a naive design would make one.
- "Multiple Order Executed Messages on the same order are cumulative" and "when the number of
  display shares for an order reaches zero, the order is dead and should be removed from the
  book". This is the residual/partial-fill contract stated as a wire invariant.
- There is a separate **Trade Message** for executions of *non-displayed* orders, because
  those never had an Add Order message to reference. Feeds are not self-consistent by
  accident; consistency is engineered.

**Time:** 2 h.

### D2. Binance — "How to manage a local order book correctly" (L2 diff + snapshot)

> Binance, USDⓈ-M Futures WebSocket Market Streams, "How to manage a local order book correctly".
> https://developers.binance.com/docs/derivatives/usds-margined-futures/websocket-market-streams/How-to-manage-a-local-order-book-correctly
> Spot equivalent: the *Diff. Depth Stream* section of
> https://developers.binance.com/docs/binance-spot-api-docs/web-socket-streams

**Status: FREE.** Doubly relevant: M1 consumes Binance as an oracle, and M2/M3 must *publish*
something a client can do this to.

The verified algorithm: open the diff stream and buffer; fetch a REST depth snapshot; discard
buffered events whose final update id `u` precedes the snapshot's `lastUpdateId`; the first
event you apply must satisfy `U <= lastUpdateId <= u`; thereafter each event's `pu` must equal
the previous event's `u`, and **if it does not, you throw the book away and start over from the
snapshot**. Quantities in each event are absolute, not deltas. Quantity zero removes the level.
And, explicitly: "receiving an event that removes a price level that is not in your local order
book can happen and is normal."

What to take: the consistency contract is `(U, u, pu)` — a per-message id *range* plus an
explicit back-pointer — and the recovery action is *resynchronise*, not *repair*. If your
`BookUpdate` event does not carry enough to let a consumer detect a gap, your L2 feed is not
correct no matter how correct your matching engine is. This is a concrete, cheap requirement to
put in your canonical schema in M0.

**Time:** 45 min including reading the surrounding stream definitions.

### D3. Coinbase Exchange `level2` channel — a *different* consistency contract

> Coinbase, Exchange WebSocket Channels.
> https://docs.cdp.coinbase.com/exchange/websocket-feed/channels

**Status: FREE.**

Read only the `level2` and `full` channel sections, then compare with D2. Coinbase sends a
`snapshot` message *on the channel itself* followed by `l2update` messages, and documents the
`level2` channel as guaranteeing delivery — a guaranteed-order channel with an in-band
snapshot, versus Binance's out-of-band REST snapshot plus gap-detection-and-restart. Same
problem, two architectures, different failure modes.

This comparison is worth 30 minutes precisely because it forces you to *choose* a contract for
CrashLab's `WS /stream` instead of inheriting one.

### D4. CME MDP 3.0 recovery — **deferrable**

> CME Group Client Systems Wiki, "MDP 3.0 – Recovery Services", "MDP 3.0 – Market Data
> Incremental Refresh – MBP and MBOFD", "MDP 3.0 – Channel Reset".
> https://cmegroupclientsite.atlassian.net/wiki/spaces/EPICSANDBOX/pages/457325847/MDP+3.0+-+Recovery+Services

**Status: FREE, partially gated (same anonymous-access caveat as B2).**

The industrial-strength version: a continuously looping snapshot feed on a separate channel,
packet sequence numbers for gap detection on the UDP incremental feed, and the rule that all
book updates within one incremental message must be applied before the book is considered
valid (i.e. a message is a transaction, not a set of independent edits). That last rule is
worth internalising even if you never implement recovery, because it is the market-data
analogue of M2's "best_bid < best_ask après une transaction atomique" invariant.

Read only if you decide to do real snapshot recovery. Otherwise defer past M3.

---

## Stage E — the economics: spread, depth, adverse selection, inventory

**All of stage E is deferrable past M2.** None of it is needed to make a matching engine
correct. All of it is needed before M6 (market maker) and M7 (cascade), and it is what turns
soutenance answers from mechanical into convincing.

### E1. Harris, Ch. 13 (Dealers), Ch. 14 (Bid/Ask Spreads) — before M6

Same book as A1, so no extra purchase.

What to take: the decomposition of the spread into order-processing costs, inventory costs
and **adverse selection** costs; why a dealer who quotes symmetrically around fair value
still loses money if the traders hitting him know more than he does; why the spread widens
with volatility and with the probability of informed trading. Ch. 14 is the source for
"what does it cost when the book is thin" as an economic rather than arithmetic statement.
This is the direct conceptual input to M6's `half_spread = base_spread + volatility_component
+ latency_component + risk_component` and to the `inventory * inventory_skew` term.

**Time:** 5–6 h for both chapters.

Also from Harris, deferrable further: **Ch. 19 (Liquidity)** and **Ch. 21 (Liquidity and
Transaction Cost Measurement)** before M8 (slippage, implementation shortfall, effective
spread — the latter two are also literally the bonus TCA rubric), and **Ch. 28 (Bubbles,
Crashes, and Circuit Breakers)** before M7.

### E2. Foucault, Pagano & Röell, *Market Liquidity* — Ch. 1, 2, 3, 6 — before M6/M8

> Thierry Foucault, Marco Pagano, Ailsa Röell, *Market Liquidity: Theory, Evidence, and
> Policy*, 2nd edition, Oxford University Press, December 2023. ISBN 978-0-19-754206-4.
> 536 pp. Listed at US $80.40 (Harvard Book Store).
> https://global.oup.com/academic/product/market-liquidity-9780197542064
> 1st edition (2013): ISBN 978-0-19-993624-3.

**Status: BUY (or borrow).** Second on the buy list, and only if you want the theory
properly. Everything Foucault covers is *also* touched by Harris, less rigorously.

Chapters, with an honesty caveat: I confirmed the second-edition part structure and chapter
titles from OUP's own listing via search, but the publisher pages 403'd my fetcher, so I could
not read the printed contents page myself. Chapter *numbers* differ between the 1st and 2nd
editions — check the TOC of whichever edition you get. The titles I am confident of:

- **Ch. 1, market structure and trading mechanics** — the academic counterpart of Harris 4+6.
- **Ch. 2, Measuring Liquidity** — quoted spread, effective spread, realised spread, price
  impact, and the fact that these are *different numbers*. Prerequisite for M8's slippage
  metric and for the TCA bonus.
- **Ch. 3, Order Flow, Liquidity, and Security Price Dynamics** — the formal adverse-selection
  story: why trades move prices permanently, and how much of the spread is compensation for
  it. This is the theory behind M6's "Adverse selection" risk column.
- **Ch. 6, Limit Order Book Markets** — the make-or-take decision as an optimisation, which is
  what your agents are implicitly solving.
- **Ch. 11, Financial Stability and Market Liquidity** (new in the 2nd edition) — liquidity
  crises and spirals. This is M7's subject matter, treated seriously.

**Time:** 3–5 h per chapter; these are equation-bearing chapters.

### E3. The two founding papers — before M6

> Lawrence R. Glosten & Paul R. Milgrom, "Bid, ask and transaction prices in a specialist
> market with heterogeneously informed traders", *Journal of Financial Economics* 14(1):71–100,
> 1985. https://www.sciencedirect.com/science/article/pii/0304405X85900443
> Free copy: https://www.edegan.com/pdfs/Glosten%20Milgrom%20(1985)%20-%20Bid%20Ask%20and%20Transaction%20Prices%20in%20a%20Specialist%20Market%20with%20Heterogeneously%20Informed%20Trades.pdf

> Albert S. Kyle, "Continuous auctions and insider trading", *Econometrica* 53(6):1315–1335,
> 1985. https://www.econometricsociety.org/publications/econometrica/1985/11/01/continuous-auctions-and-insider-trading
> Free copy: https://people.duke.edu/~qc2/BA532/1985%20EMA%20Kyle.pdf

**Status: FREE** (author/course copies; the journals themselves are paywalled).

Read Glosten-Milgrom first, and read it for **one result**: a bid/ask spread appears even
when the market maker is risk-neutral, has zero inventory cost and earns zero expected
profit — purely because some of the traders hitting him are better informed. That is
adverse selection in its purest form, and it is the reason your M6 market maker must widen
rather than merely re-centre when informed flow arrives.

Read Kyle for **one object**: the price-impact coefficient λ, "Kyle's lambda", where price
moves linearly in net order flow and 1/λ is a measure of market depth. λ is the cleanest
formalisation of the ticket's question "what does it cost when the book is thin", and it is
what M7's cascade is a runaway feedback in.

Don't grind the proofs. Read the setup, the statement, the interpretation sections.

**Time:** 3–4 h for both if you read them for the ideas.

### E4. Inventory and quoting — before M6

> Thomas Ho & Hans R. Stoll, "Optimal dealer pricing under transactions and return
> uncertainty", *Journal of Financial Economics* 9(1):47–73, 1981.
> https://www.sciencedirect.com/science/article/abs/pii/0304405X81900209

> Marco Avellaneda & Sasha Stoikov, "High-frequency trading in a limit order book",
> *Quantitative Finance* 8(3):217–224, 2008. DOI 10.1080/14697680701381228.
> Free copy: https://people.orie.cornell.edu/sfs33/LimitOrderBook.pdf

> Álvaro Cartea, Sebastian Jaimungal, José Penalva, *Algorithmic and High-Frequency Trading*,
> Cambridge University Press, 2015. ISBN 978-1-107-09114-6. **Ch. 10 "Market making"**
> (and Ch. 1 "Electronic markets and the limit order book" if you want a second, more
> mathematical pass over stage A).

**Status:** Ho & Stoll paywalled (JFE); Avellaneda-Stoikov **free** at the Cornell link above;
Cartea et al. **must buy** — and it is genuinely optional, only worth it if you want the
stochastic-control treatment.

What to take: Ho & Stoll is the origin of *inventory risk* as distinct from adverse selection
— a dealer skews his quotes away from his current inventory not because he is informed but
because he is exposed. Avellaneda-Stoikov turns that into an explicit reservation price
`s - q·γ·σ²·(T-t)` and an optimal spread, which is recognisably the same shape as M6's
`fair_value = reference_price + local_order_flow_adjustment - inventory * inventory_skew`.
Read Avellaneda-Stoikov *after* Ho & Stoll's intuition, and read it to justify your
`inventory_skew` parameter rather than to copy the formula — the paper's model assumes a
single venue and no funding, neither of which holds in CrashLab.

**Time:** Avellaneda-Stoikov ≈ 3 h. Ho & Stoll ≈ 2 h, or skip and get the intuition from
Harris Ch. 13. Cartea Ch. 10 ≈ 6 h.

### E5. Bouchaud, Bonart, Donier & Gould, *Trades, Quotes and Prices* — Ch. 3, 4, and Part VII — before M5/M7

> Jean-Philippe Bouchaud, Julius Bonart, Jonathan Donier, Martin Gould, *Trades, Quotes and
> Prices: Financial Markets Under the Microscope*, Cambridge University Press, 2018.
> https://www.cambridge.org/core/books/trades-quotes-and-prices/029A71078EE4C41C0D5D4574211AB1B5

**Status: BUY** (Cambridge Core access if your institution has it). Deferrable.

Confirmed structure: Part I (Ch. 1 The Ecology of Financial Markets, Ch. 2 The Statistics of
Price Changes), **Part II Limit Order Books: Introduction (Ch. 3 Limit Order Books, Ch. 4
Empirical Properties of Limit Order Books)**, Part III Limit Order Books: Models (Ch. 5
Single-queue dynamics: simple models, Ch. 6 Single-queue dynamics for large-tick stocks),
Part IV Clustering and Correlations, Part V Price Impact, Part VI Market Dynamics at the
Micro-Scale (incl. Ch. 13 The Propagator Model), **Part VII Adverse Selection and Liquidity
Provision**, Part VIII Market Dynamics at the Meso-Scale, Part IX Practical Consequences.

I could confirm the part titles and chapters 1–6 and 13 individually; I did not verify the
chapter *numbers* inside Part VII, so refer to it by part name.

What to take: Ch. 3 and 4 are the best available empirical description of what a real book
*looks like* — the shape of the depth profile, the distribution of order sizes, cancellation
rates, the ratio of cancels to fills (overwhelmingly cancels). You need those numbers to
calibrate M5's 200–1000 agents so the book is plausible rather than arbitrary; the models are
calibrated on recent Nasdaq data. Part VII is the modern treatment of adverse selection and
liquidity provision and complements E3.

**Time:** Ch. 3+4 ≈ 6 h.

---

## Stage F — the four prices

Short, and worth reading early (it is 90 minutes total) even though implementation lands in
M4. **Overlaps with issue `04-reading-perpetuals-margin-liquidation.md`** — that ticket owns
funding, margin and liquidation mechanics; this section covers only the *price definitions*,
because they are what soutenance questions 1 and 2 target.

### F1. BitMEX, "Fair Price Marking"

> BitMEX, Fair Price Marking. https://www.bitmex.com/app/fairPriceMarking
> (also served at https://www.services.bitmex.com/app/fairPriceMarking)
> Companion: "What is Last, Index, and Mark Price?"
> https://support.bitmex.com/hc/en-gb/articles/7147348807197-What-is-Last-Index-and-Mark-Price

**Status: FREE.** Read this one first, and read it as CrashLab's thesis statement written by
the venue that invented the mechanism.

BitMEX documents, in its own words, that Fair Price Marking exists "for the purpose of
avoiding liquidation due to illiquid markets or manipulation"; that the last traded price
"can deviate from the underlying index price due to market dynamics on the BitMEX order
book"; and it defines three marking methods — Last Price, **Last Price Protected**, and Fair
Price — where Fair Price = Index Price + a basis derived from the *Impact Mid Price*, updated
only when the impact bid/ask spread is tighter than the maintenance margin (or 3 ticks,
whichever is larger).

This is exactly CrashLab's Exchange A vs Exchange B experiment, documented by a real exchange
that shipped the fragile version first and then fixed it. `mark_price_A = local_last_traded_price_A`
is BitMEX's "Last Price" mode; `mark_price_B = reference_price + clamp(EMA(local_mid − reference), ±max_basis)`
is a simplified Fair Price. Note that BitMEX gates the basis update on *spread width* — a
liquidity condition — where CrashLab's Exchange B gates on *magnitude* via `clamp`. Different
guard, same intent; being able to discuss that difference is a strong soutenance answer.

**Answers soutenance question 2 directly.** 30 min.

### F2. Binance — Index Price and Mark Price

> Binance USDⓈ-M Futures, Mark Price REST endpoint:
> https://developers.binance.com/docs/derivatives/usds-margined-futures/market-data/rest-api/Mark-Price
> Mark Price WebSocket stream:
> https://developers.binance.com/docs/derivatives/usds-margined-futures/websocket-market-streams/Mark-Price-Stream
> COIN-M "Index Price and Mark Price":
> https://developers.binance.com/docs/derivatives/coin-margined-futures/market-data/rest-api/Index-Price-and-Mark-Price

**Status: FREE.**

What to take: the **index price** is a volume-weighted average across several *external*
constituent spot venues — that is your `reference_price`, and it is constructed precisely so
that no single venue's book can move it. The mark price is then a function of the index plus
a moving-average premium. The stream also carries `estimatedSettlePrice`, `lastFundingRate`
and `nextFundingTime`, which is a useful sanity check on the shape of your own
`MarkPriceUpdate` event in Annexe A.

Caveat, flagged honestly: Binance has revised its mark-price and funding formulas more than
once (there is a September 2025 announcement to that effect), so read the *current* docs
rather than any write-up, and record the date you read them in your report.

**Answers soutenance question 1** — why the external price must not be injected into the
local book: because if it were, the local book's mid would be a function of the index, the
index is a function of *other* venues' books, and your exchange would have no independent
price at all. Everything CrashLab measures (basis, funding, cascade) would be identically
zero by construction.

**Time:** 45 min.

### F3. The fourth price is yours

There is no external source for **local mid vs local last traded price** as a *design
decision*, because on a real venue nobody is asked to choose. The material you need is
already in Harris Ch. 4 (best bid, best offer, spread, trade prices) and Gould §II.C (when
$b(t)$, $a(t)$ and the mid can change, versus when a transaction price is recorded). The
thing to write down for yourself, in one page, before M2:

- **reference price** — external, read-only, moves without any local event.
- **local mid** — `(best_bid + best_ask)/2`; moves on *any* book event including a pure
  cancel; undefined when a side is empty (decide what you publish then — this is a real bug
  source).
- **local last traded price** — moves *only* on a local trade; is stale by construction
  between trades; is a single tick of a single counterparty's aggression.
- **mark price** — a *policy*, not an observation. Both A and B compute it; they disagree;
  that disagreement is the project.

---

## Ordering summary

### Prerequisite before writing the matching engine (M2)

| # | Source | Free? | Time |
|---|---|---|---|
| A1 | Harris Ch. 2, 3 (skim), 4, 6 | **buy** | 10–12 h |
| A2 | Gould et al. §II, §III.D, §III.E | free | 3 h |
| B1 | Nasdaq Equity 4 Rules 4702/4703/4757 | free | 1 h |
| B2 | CME Globex Matching Algorithms + Algorithm Steps | free | 1.5 h |
| B3 | Eurex "Matching principles" | free | 0.25 h |
| B4 | Deribit order-management docs | free | 0.5 h |
| C1 | FIX 4.4 Appendix D (sections A–D careful, E–L skim) | free | 3–4 h |
| C2 | Nasdaq OUCH 5.0 §1, §2.1–2.3, §3.1–3.13 | free | 2–3 h |
| D1 | Nasdaq TotalView-ITCH 5.0 §1.3–1.5 | free | 2 h |
| D2 | Binance "How to manage a local order book correctly" | free | 0.75 h |
| D3 | Coinbase Exchange `level2` channel | free | 0.5 h |
| F1 | BitMEX Fair Price Marking | free | 0.5 h |
| F2 | Binance Index Price / Mark Price | free | 0.75 h |
| F3 | Write your own one-pager on the four prices | — | 1 h |

**≈ 28–32 hours, one book to buy.** M3 (Exchange B) needs nothing beyond this — it is the
same mechanics in a different runtime.

### Useful but deferrable

| Before | Source | Free? | Time |
|---|---|---|---|
| M5 | Gould et al. §IV (empirical observations), §V (models incl. zero-intelligence and agent-based) | free | 5 h |
| M5 | Bouchaud et al. Ch. 3, 4 | buy | 6 h |
| M6 | Harris Ch. 13, 14 | (already bought) | 5–6 h |
| M6 | Glosten & Milgrom 1985; Kyle 1985 | free | 3–4 h |
| M6 | Ho & Stoll 1981; Avellaneda & Stoikov 2008 | AS free, HS paywalled | 3–5 h |
| M6 | Cartea, Jaimungal & Penalva Ch. 10 (optional) | buy | 6 h |
| M7 | Harris Ch. 28; Foucault et al. Ch. 11 | buy | 6 h |
| M7 | Bouchaud et al. Part VII (adverse selection & liquidity provision) | buy | 5 h |
| M8 | Harris Ch. 19, 21; Foucault et al. Ch. 2 | buy | 8 h |
| if doing feed recovery | CME MDP 3.0 recovery pages | free | 2 h |
| optional | Eurex T7 Functional Reference | free | 3 h |

---

## What I deliberately excluded, and why

- **Any "build a matching engine in <language>" tutorial.** The ones I found treat cancel,
  cancel/replace, the residual, and the pending states as afterthoughts or omit them
  entirely — which is precisely the part of M2 that carries the marks. The FIX and OUCH specs
  cover the same ground correctly and are shorter.
- **Investopedia / exchange-marketing explainers on mark price and liquidation.** They assert
  the formula without the failure mode. BitMEX's own Fair Price Marking page states the
  failure mode explicitly, so there is no reason to read a paraphrase.
- **Maureen O'Hara, *Market Microstructure Theory* (Blackwell, 1995).** Frequently
  recommended, and probably good, but I could not verify its chapter titles from any source I
  could actually read, and the ticket forbids guessing. Foucault et al. covers the same
  theory more recently and I *could* verify its structure. If you already own O'Hara, its
  inventory and information chapters substitute for E3.
- **WK Selph, "How to Build a Fast Limit Order Book" (2011).** The most-cited engineering
  write-up on order-book data structures. I could not verify a live canonical copy: the
  original `howtohft.wordpress.com` is gone, the `howtohft.blogspot.com` page is only a
  redirect notice, and the quantcup.org mirror
  (http://www.quantcup.org/home/howtohft_howtobuildafastlimitorderbook) returned empty to my
  fetcher. **I have not read it and cannot vouch for it.** If you find it, it is reportedly
  about achieving O(1) add/cancel/execute via an intrusive doubly-linked list of orders per
  price level plus a map from order id to node — a design you can derive yourself from ITCH's
  message set in an afternoon, which is what I'd suggest doing instead.
- **dYdX v4 `x/clob`** (https://github.com/dydxprotocol/v4-chain, `protocol/x/clob/memclob`).
  A real open-source perpetuals CLOB in Go, which is tempting as a reference implementation.
  I checked: there is **no README or written spec** at `protocol/x/clob/` or
  `protocol/x/clob/spec/` (both 404). Reading it means reading the source cold. Listed here
  so you know it exists; not recommended as a *reading* source.

---

## Explicit uncertainties in this list

Stated plainly rather than smoothed over:

1. **Foucault, Pagano & Röell chapter numbers.** Confirmed from OUP's own listing via search
   snippets; the publisher pages returned 403/empty to my fetcher so I did not read the
   printed contents page. Chapter numbering differs between the 2013 1st edition and the
   2023 2nd edition. Verify against the TOC of your copy. Chapter *titles* for 1, 2, 3, 6 and
   11 I am confident of; there is minor variation in reported wording of Ch. 1's title
   ("Trading Mechanics and Market Structure" vs "Market structure and trading mechanics").
2. **Bouchaud et al. Part VII chapter numbers** — unverified. Chapters 1–6 and 13 verified
   individually on Cambridge Core; refer to Part VII by name.
3. **Nasdaq rulebook accessibility.** listingcenter.nasdaq.com returns 403 to non-browser
   clients. I verified Rules 4702/4703/4757 exist and verified the substance of 4757's
   price/display/time algorithm from SEC rule-filing exhibits and search snippets, not from
   the live page.
4. **CME wiki gating.** Both the matching-algorithm and MDP 3.0 pages load anonymously but
   warn that some content may be blocked without an account. I confirmed the section
   structure and the existence of the FIFO/Pro-Rata worked examples; I cannot promise every
   table renders for you.
5. **Eurex "Matching principles" is shorter than its reputation.** What I actually retrieved
   is about one page covering time, pro-rata and time-pro-rata, with **no worked numeric
   examples**. Secondary write-ups suggest otherwise. Budget 15 minutes, not an hour.
6. **Harris list price** not verified — the OUP product pages returned empty to my fetcher.
   Publisher, year (2003), ISBN (0-19-514470-8) and page count (643) are verified.
7. **Ho & Stoll (1981) page range** — sources disagree between 47–73 and 99–117. The
   preponderance, including RePEc's JFE 9(1) record, gives **47–73**; I have used that.
8. **Binance mark-price formula is a moving target.** Do not cache it; cite the date you read
   the doc.
