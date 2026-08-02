# Can Simplx be made deterministic?

Type: task
Status: open
Blocked by: 01

## Question

Graduated from the fog by ticket 06, which read the Simplx source and found that
**cross-core event ordering is not documented and appears timing-dependent**.
That agent flagged the claim as inference from reading, not an empirical result,
and recommended a single-core matching engine plus an explicit sequencer.

This matters more than its origin suggests. The subject requires that the same
oracle file, config, seed and worker count produce **the same functional hash** —
same decisions, orders, fills, liquidations and PnL. Non-deterministic replay
**caps the entire project at 70/100**, and it is the second-hardest cap to
recover from after failing to build at all.

So: can Simplx deliver deterministic event ordering, and at what cost?

**What to establish empirically:**

1. **Is cross-core delivery order actually stable?** Write a small harness: two
   or more actors on different cores pushing events to a common consumer, run it
   many times, hash the received sequence. If the hash varies, ordering is
   timing-dependent and confirmed.
2. **Is single-core delivery order stable?** If yes, the fallback — pin matching
   to one core — is viable, and the question becomes what it costs in throughput
   given the benchmark targets 1000 agents.
3. **What does an explicit sequencer cost?** If every event carries a
   monotone sequence per producer (the subject mandates this field anyway) and
   the consumer reorders into a deterministic merge, is that affordable on the
   critical path? Note the subject forbids disk, network, console I/O and global
   mutexes inside matching handlers.
4. **`TimerProxy` is wall-clock driven** (see ticket 01). Confirm that scenario
   events on a simulated clock can replace it entirely, because if any timer
   remains in the loop, replay cannot be deterministic.
5. **Are there other non-determinism sources in the framework?** Unordered
   container iteration, address-dependent ordering, thread-startup races,
   allocation-order dependence.

**Why this is a route question and not a build question:** if Simplx cannot be
made deterministic at acceptable cost, the route must either put Exchange A on a
different foundation, or accept the 70-point cap and say so explicitly, or make
"determinism" a deliberate, taught, early step rather than something assumed to
come free. All three produce a materially different route. Deciding which is in
scope; designing the sequencer is not.

**Blocked because:** nothing can be measured until Simplx builds and runs
(ticket 01).
