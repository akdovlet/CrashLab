# What one route step looks like on the page

Type: prototype
Status: open
Blocked by: —

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
