# Full depth or minimum viable, per milestone

Type: grilling
Status: open
Blocked by: 09

## Question

There is no deadline, but there is still finite attention. Not every milestone
repays the same depth of study, and the route should say so explicitly rather
than implying all eleven deserve equal weight.

**The obvious candidates for reduced depth:**

- **M10, KYC/AML (4 pts).** State machine, RBAC, field encryption, retention
  policy, audit trail, admin panel. Genuine engineering, but it teaches nothing
  about markets and the subject itself warns the result must never claim to be
  legally compliant. Is there a version of this that is a one-week checkbox, or
  is regulatory workflow a thing worth understanding on its own terms?
- **M9, options (4 pts).** Black-Scholes, delta, intrinsic vs time value,
  implied vol by bisection, a straddle and delta-hedging. Only 4 points, but the
  concepts are foundational to derivatives generally and this may be the only
  time they get touched. Deep detour or quick pass?
- **M6, the global market maker (8 pts).** Adverse selection and inventory skew
  are genuinely deep topics that could absorb unlimited time.

**The obvious candidates for extra depth beyond what scoring justifies:**

- **M0, infrastructure and replay (5 pts).** Worth only 5 points, but
  non-deterministic replay caps the entire project at 70 and an unreconcilable
  ledger invalidates the whole financial section. Its leverage massively exceeds
  its score, and event-sourcing/determinism is transferable knowledge.
- **M4 and M7 together.** The project's actual thesis. Worth 25 points combined
  and arguably worth more attention than that.

**What this ticket must settle:** a depth tier per milestone — something like
*deep / standard / checkbox* — with the reasoning. The route document states the
tier per step so that expectations are set before the work starts, rather than
discovered halfway through.

Also worth deciding: does "checkbox" depth mean *implement it and move on*, or
does it mean *implement it later, after the interesting milestones are done*?
Those are different, and the second reorders the route.

**Blocked because:** judging what each milestone teaches requires the concept
graph (ticket 09).
