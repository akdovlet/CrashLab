# The ten soutenance questions, mapped to route steps

Type: task
Status: open
Blocked by: 09

## Question

The ten defence questions in §7 of the subject are the route's understanding
gates — the agreed measure of "learned". Each must be attached to the step that
earns the right to answer it, and each needs a rubric: what does a *good* answer
contain?

The questions, verbatim from the subject:

1. Why must Binance's price never be injected directly into the local book?
2. Why should local last price and mark price not always be identical?
3. How do you prevent a double fill after a retry?
4. What is the difference between initial margin, maintenance margin and equity?
5. Why is open interest alone insufficient to precisely predict liquidations?
6. How does the market maker measure its unhedged risk?
7. Why is an average latency insufficient?
8. How did you aggregate VaR between A and B?
9. Which optimisation did you measure rather than merely assume?
10. Which assumption in your model is the most fragile?

**The work:**

- Attach each question to a step. Most map cleanly (1 → M1 oracle, 3 → M0/M2
  idempotency, 4 → M4 margin, 6 → M6 market maker, 8 → M8 VaR). Question 2 spans
  M1 through M7 and may need to be asked twice at increasing depth.
- Note that **questions 9 and 10 cannot be pre-answered** — they are about work
  actually done. They are not learning gates in the same sense; they are prompts
  to keep a running log. Decide how the route handles that: probably a standing
  instruction to record every measured optimisation and every known-fragile
  assumption as they occur, rather than reconstructing them at the end.
- Write a rubric per question — two or three sentences on what distinguishes an
  answer that demonstrates understanding from one that recites the formula.
  Question 4 in particular has a recitable answer that proves nothing; a good
  answer explains why maintenance margin is lower than initial margin and what
  the gap is *for*.
- Flag any concept in the graph that **no** soutenance question tests. Those are
  blind spots in the gate system, and the route may want to invent an additional
  gate to cover them.

**Blocked because:** the mapping depends on the concept dependency graph
(ticket 09), which determines what each step actually teaches.
