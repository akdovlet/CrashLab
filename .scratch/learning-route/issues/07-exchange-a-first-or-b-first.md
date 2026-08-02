# Exchange A first, or Exchange B first?

Type: grilling
Status: open
Blocked by: 01, 06

## Question

The subject numbers M2 (Exchange A, C++17 + Simplx, 13 pts) before M3
(Exchange B, Python asyncio, 8 pts), and states that each milestone must work
before the next. Should the route follow that order?

**The case for inverting it — B first:**

Building Exchange B first means learning the *domain* — price-time priority,
the order state machine, partial fills, accounts, positions — in Python, where
the language is not also fighting you. Then Exchange A becomes a re-implementation
of a problem you already understand, and the only new thing is C++17 and the
actor model. Learning two hard things at once is how people stall.

The subject also requires the two exchanges to be functionally compatible —
same product, tick sizes, order types and events. Whichever is built first
defines the protocol in practice, and a protocol discovered in Python is cheaper
to change than one discovered in C++.

**The case for following the subject — A first:**

A is the larger, harder, higher-scoring component, and momentum matters. Doing
the hard thing while fresh is a real argument. There is also a risk that a
Python-first protocol is shaped by Python's conveniences and fits C++ badly —
the subject's own event structs are C-style with `int64_t` fields, which hints
the protocol should be designed C-first.

**A third option:** build a throwaway toy matching engine first, in whichever
language, deliberately incomplete — no margin, no actors, no persistence — purely
to make price-time priority and partial fills concrete. Then start the real work
with the domain already understood. This is currently sitting in the map's fog.

**What this ticket must settle:** the order, and the reasoning, in a form that
can be written into the route document. It should also say what the *protocol*
work (M0) looks like given that order, since M0 is what makes the two exchanges
compatible.

**Blocked because:** the answer depends on how much of a fight Simplx will be
(ticket 01) and how large the modern-C++ on-ramp turns out to be (ticket 06).
If Simplx is a liability, or the C++ gap is bigger than expected, B-first
becomes close to forced.
