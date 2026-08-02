# Read-first or build-first?

Type: grilling
Status: open
Blocked by: —

## Question

The destination commits to steps that pair "learn / read" with "build". It does
not say in what proportion, or in what order *within* a step. That cadence
decision shapes every step of the route, so it needs settling early.

**The positions:**

- **Read first, then build.** Understand margin properly before implementing it,
  and the implementation is a transcription rather than an exploration. Risk:
  reading about liquidation mechanics with no code to hang it on is abstract and
  forgettable, and a reading phase with no output is where motivation dies —
  especially with no deadline to enforce movement.

- **Build first, read when stuck.** Write a naive version, discover why it is
  wrong, then read the source that explains it. Retention is far better because
  the reading answers a question you actually have. Risk: you can build a naive
  version of a matching engine and never discover it is wrong, because nothing
  tells you. Some errors are silent — this project's entire thesis is that a
  *correct* matching engine can still be dangerous, which is exactly the kind of
  thing building alone will not reveal.

- **Spike, read, then build properly.** A deliberately throwaway spike to
  generate questions, then reading, then the real implementation. Costs a third
  more time; with no deadline that may be affordable.

**Considerations to put to the user:**

- Does the answer differ by *kind* of material? Modern C++ may reward build-first
  (the compiler tells you when you are wrong); margin and liquidation mechanics
  may demand read-first (nothing tells you when you are wrong).
- Does it differ by *stakes*? The subject's grading caps mean a non-deterministic
  replay or an unreconcilable ledger poisons everything downstream. Those may
  deserve read-first regardless.
- What is the failure mode this developer actually has? Someone who reads
  forever and never ships needs a different cadence from someone who builds fast
  and never consolidates. This is a question only the user can answer.
- Where do the understanding gates sit — do you attempt the soutenance question
  *before* building the step (as a diagnostic of what you don't know) or after
  (as verification)? Doing both is defensible.

**What this ticket must settle:** the default cadence, plus any named exceptions,
in a form the route document can state once and then rely on.
