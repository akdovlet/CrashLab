# Assemble the route document

Type: task
Status: open
Blocked by: 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12

## Question

Every decision is made; write the route.

This ticket is deliberately mechanical. If it turns out to require *decisions*
rather than assembly, something upstream was left unresolved and should be
raised as a new ticket instead of quietly settled here.

**Inputs:** the format settled by ticket 02, the build order from 07, the
cadence from 08, the concept graph from 09, the gates from 10, the depth tiers
from 11, the skill placements from 12, the reading lists from 03/04/05, and the
Simplx verdict from 01.

**The output** — a document at a location to be decided (likely `docs/`,
since unlike the map it is a durable artefact rather than working state) with:

- A short preamble: what CrashLab is, what the thesis is, what the reader is
  expected to already know, and how to use the document.
- The steps, in order, in the format from ticket 02.
- The standing rules that apply across all steps — the cadence from 08, the
  financial constraints the subject imposes everywhere (scaled integers or
  explicit decimals, never binary floats in the ledger or margin checks; every
  cash and position movement traceable to an immutable event; an execution
  counted exactly once even after retry or reconnect), and the running log for
  soutenance questions 9 and 10.
- The grading caps as a checklist, positioned as constraints satisfied on the
  way rather than goals.
- An explicit statement of what the route does *not* cover, so its edges are
  visible.

**A note on honesty:** the route will be long and it will be walked by one
person with no deadline. It should say plainly which steps are the hard ones and
where the effort actually concentrates, rather than presenting eleven milestones
as an even sequence. M4 and M7 together are the project; most of the rest is
scaffolding that makes them possible.
