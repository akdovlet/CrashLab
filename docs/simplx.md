# Simplx, from the ground up

A lesson on the actor framework Exchange A is built on. Written against the
vendored source at `vendor/simplx/` (upstream `ff9d5bf`, Sept 2019), for someone
fluent in C++98 and new to both the actor model and C++11/17.

Everything here is checked against the source. File and line references point at
`vendor/simplx/`.

---

## Part 1 — The problem Simplx exists to solve

### 1.1 Why concurrency in C++ is miserable

The way you were taught to make a program use several cores is: start threads,
put shared data behind a mutex, lock before touching it, unlock after.

```cpp
std::mutex        book_mutex;
OrderBook         book;              // shared

void on_order(const Order &o) {
    std::lock_guard<std::mutex> lk(book_mutex);
    book.insert(o);
}
```

This is correct and it is also a trap. The problems are not bugs you can find by
staring harder:

- **Every lock is a serialisation point.** Two cores that both want the book run
  one at a time. Add cores, get no throughput. You bought parallelism and
  received queueing.
- **Locks compose badly.** Two mutexes taken in different orders by two threads
  is a deadlock, and nothing in the type system warns you.
- **Cache lines bounce.** When core 0 writes a variable core 1 has cached, the
  hardware must invalidate and re-fetch a 64-byte line. A shared counter
  incremented from four cores can be slower than from one.
- **Bugs are not reproducible.** A race that fires once in 10⁸ interleavings is
  not a bug you debug. It is weather.

For an exchange this is not an inconvenience — it is disqualifying. An exchange
must be *fast* and *explainable*. "It filled in the wrong order and we don't know
why" is not an acceptable sentence.

### 1.2 The actor model, in one idea

The actor model removes shared mutable state from the picture:

> Split the program into **actors**. An actor owns its state privately. Nobody
> else can touch it. Actors communicate **only** by sending each other
> **messages**. Each actor processes one message at a time, to completion.

Everything follows from that. If no two threads can touch the same data, there
is nothing to lock. If there is nothing to lock, there is no deadlock, no
contention, and no data race — not "fewer", *none*, structurally. Each actor is a
single-threaded program, and single-threaded programs you already know how to
reason about.

The cost is that everything becomes asynchronous. You cannot ask another actor a
question and wait for the answer; you send it a message and, later, receive one
back. Control flow that was a function call becomes a state machine. That is the
trade, and it is the thing you are actually learning.

This idea is old (Hewitt, 1973) and mainstream elsewhere: Erlang, Akka on the
JVM, Microsoft Orleans, Rust's Actix. Simplx is a C++ take on it.

### 1.3 Simplx's specific bet

Simplx is not a general actor library. It was built by Tredzone for the Paris
stock exchange — Euronext's Optiq platform has run on it since November 2016 —
and it makes choices that only make sense for low-latency trading:

| Choice | Consequence |
|---|---|
| **One OS thread per CPU core, pinned** | No thread pool, no migration, no scheduler surprises |
| **The thread never blocks or sleeps** | It spins. Latency is not a syscall away. **Each core sits at 100% CPU** |
| **Run to completion** | A handler runs start to finish; it is never preempted mid-way |
| **Events allocated from per-core pages** | No `malloc` on the hot path, cache-friendly |
| **No locks anywhere in user code** | Cross-core handoff uses a batched double-buffer, not mutexes |

That last row deserves emphasis. In your Exchange A code you will not write
`std::thread`, `std::mutex`, `std::atomic`, `std::condition_variable`, or
`std::future` — not once. The framework structurally removes the need. For
someone coming from C++98 this is the best possible property: you get real
multicore without first having to master the hardest part of modern C++.

> **The busy-spin is measured, not theoretical.** Tutorial 10 idling on a
> once-per-second timer: 7.90 s user time over 7.91 s wall, 99% CPU. Budget one
> fully-consumed core per core you start.

---

## Part 2 — The mental model

Five nouns carry the whole framework. Learn these and the rest is detail.

```
   Engine                  the runtime. Owns the threads. One per process.
     └── Core 0            one pinned OS thread, one event loop
     |     ├── Actor A     private state + handlers
     |     └── Actor B
     └── Core 1
           └── Actor C

   Event                   an immutable message. A struct deriving Actor::Event.
   Pipe                    a one-way addressed channel you push Events into.
   Service                 an empty tag type that gives an actor a findable name.
```

And the one-sentence version of how work happens:

> An actor **registers a handler** for an event type, another actor **pushes**
> that event into a **pipe** addressed at it, and the **engine's event loop**
> delivers it by calling `onEvent`.

Here is a complete program. This is tutorial 08 (`tutorial/08_pingpong/`),
lightly trimmed — an event travels core 1 → core 2 → core 1:

```cpp
#include "simplx.h"
using namespace tredzone;

// 1. THE MESSAGE
struct TravelLogEvent : Actor::Event {
    TravelLogEvent(const std::string &place) : visited(place) {}
    std::string visited;
};

// 2. THE SERVICE TAG — an empty type used as a name
struct PongTag : Service {};

// 3. AN ACTOR THAT RECEIVES AND REPLIES
class PongActor : public Actor {
public:
    PongActor() {
        registerEventHandler<TravelLogEvent>(*this);      // "route these to me"
    }
    void onEvent(const TravelLogEvent &e) {               // called by the loop
        Event::Pipe pipe(*this, e.getSourceActorId());    // channel back to sender
        pipe.push<TravelLogEvent>(e.visited + ", visited Pong @ core #"
                                  + std::to_string((int)getCore()));
    }
};

// 4. AN ACTOR THAT STARTS THE CONVERSATION
class PingActor : public Actor {
public:
    PingActor() {
        registerEventHandler<TravelLogEvent>(*this);
        const ActorId dest = getEngine().getServiceIndex()
                                 .getServiceActorId<PongTag>();   // find by tag
        Event::Pipe pipe(*this, dest);
        pipe.push<TravelLogEvent>("started in Ping");
    }
    void onEvent(const TravelLogEvent &e) {
        std::cout << "travel log: " << e.visited << ", ended back in Ping\n";
    }
};

// 5. WIRING
int main() {
    Engine::StartSequence startSequence;
    startSequence.addServiceActor<PongTag, PongActor>(2);   // Pong on core 2
    startSequence.addActor<PingActor>(1);                   // Ping on core 1
    Engine engine(startSequence);                           // <- threads start here
    std::cin.get();
    return 0;                                               // <- shutdown here
}
```

Note what is *absent*: no thread, no lock, no queue, no `join()`. Note also that
`PingActor`'s constructor already sends a message — actors are live from the
moment they are constructed.

---

## Part 3 — The lifecycle

### 3.1 Startup

`Engine::StartSequence` is a *recipe*, not a running system. You fill it in on
the main thread, then hand it to the `Engine` constructor, which is where threads
are actually created.

```cpp
Engine::StartSequence seq;              // nothing running yet
seq.addActor<GatewayActor>(0);          // "when you start, put one of these on core 0"
seq.addServiceActor<BookTag, MatchingEngineActor>(1);
Engine engine(seq);                     // NOW: threads spawn, actors constructed
```

Two important guarantees, documented at `engine.h:530-539`:

- Actors are constructed **in strict declaration order**.
- **Service actors are destroyed after all non-service actors**, and in strict
  reverse declaration order. Non-service actors have *no* destruction-order
  guarantee.

That is why long-lived infrastructure — the matching engine, the account service,
the timer — should be service actors: it guarantees they outlive their clients.

### 3.2 The event loop, precisely

This is the heart of the machine, and it is worth knowing exactly. The default
loop (`src/engine/engine.cpp:200`) is:

```cpp
while (isRunning())
    do { asyncNode->synchronize(); } while (!*interruptFlag);
```

`synchronize()` (`include/trz/engine/internal/node.h:899`) is two halves:

```
synchronizePreBarrier()
    1. synchronizeUsageCount()          bump loop counters
    2. synchronizeAsyncActorCallbacks() run every registered Callback once
    3. synchronizeLocalEvents()         deliver same-core events -> onEvent()
    4. publish this core's write-cache so other cores can read it

synchronizePostBarrier()
    5. read other cores' caches, deliver cross-core events -> onEvent()
    6. synchronizeDestroyAsyncActors()  actually destroy actors that accepted destroy
```

Consequences you should internalise:

- **Destruction happens at a defined point** — step 6, at the end of a loop
  iteration. Never inside a handler. That is why `requestDestroy()` is a
  *request*, and why an actor can safely keep running after asking to die.
- **Callbacks fire before events** each iteration.
- **Same-core messaging is a pointer append.** Sending to an actor on your own
  core does not cross a cache line boundary or synchronise anything.
- **Cross-core messaging is batched**, not per-message. Events accumulate in a
  per-(writer,reader) `WriteCache` (`node.h:154`) and are handed over once per
  loop iteration. That is where the throughput comes from — the handoff cost is
  amortised over a whole batch.

### 3.3 Shutdown

`~Engine()` starts shutdown. Two things then become true:

- **No new actors can be created.** `newReferencedActor` and friends throw
  `Actor::ShutdownException` (`actor.h:305`). This is deliberate: an actor that
  spawns a replacement on the way out would live-lock the shutdown.
- Every actor is asked to die via `onDestroyRequest()`, services last.

For a *deterministic* exit — which CrashLab needs — an actor overrides
`onDestroyRequest()` and decides. Tutorial 09:

```cpp
void onDestroyRequest() noexcept override {
    if (m_Done) acceptDestroy();   // yes, I'm finished
    else        requestDestroy();  // not yet — ask me again next loop
}
```

The default implementation just calls `acceptDestroy()`. Overriding it is how you
guarantee an in-flight order is not abandoned mid-match.

---

## Part 4 — The reference: every class and keyword

### 4.1 A naming note

You will see `AsyncNode`, `asyncActor`, `AsyncNodesHandle` all over the internals.
**"Async" is a legacy prefix with no meaning** — the framework used to be called
something else. Also:

| Term | Means |
|---|---|
| **Core** (`CoreId`) | a physical CPU core. `uint8_t`, arbitrary value (`actor.h:268`) |
| **Node** (`NodeId`) | Simplx's *compact index* for a started core, 0..N-1 (`actor.h:270`) |
| **Node** (internal `AsyncNode`) | the event loop + its actors on one core |

"Node" and "core" are used almost interchangeably in the source. There is no
network node; a Simplx node is a core.

### 4.2 `Engine` — the runtime

```cpp
Engine engine(startSequence);
```

One per process. Owns the threads. Constructing it starts everything; destroying
it stops everything.

| Member | What it is |
|---|---|
| `Engine::StartSequence` | the configuration recipe (see below) |
| `Engine::CoreSet` | a set of core-ids to use |
| `Engine::FullCoreSet` | `CoreSet` pre-filled with every available core (the default) |
| `Engine::ServiceIndex` | the registry mapping service-tags → `ActorId` |
| `getServiceIndex()` | reach the registry, usually via `getEngine().getServiceIndex()` |
| `DEFAULT_EVENT_ALLOCATOR_PAGE_SIZE` | 64 KB — the event page size |

### 4.3 `Engine::StartSequence` — the recipe

| Method | Purpose |
|---|---|
| `addActor<A>(coreId)` | start one `A` on that core |
| `addActor<A, Init>(coreId, init)` | …passing `init` to `A`'s constructor |
| `addServiceActor<Tag, A>(coreId)` | …and register it in the service index under `Tag` |
| `addServiceActor<Tag, A, Init>(coreId, init)` | both |
| `setExceptionHandler(h)` | install an `AsyncExceptionHandler` |
| `setEventAllocatorPageSizeByte(n)` | tune the 64 KB event page |
| `setThreadStackSizeByte(n)` | thread stack size |
| `setRedZoneCore(coreId)` | mark a core real-time-scheduled ("red zone") |
| `setBlueZoneCore(coreId)` | mark it normal |
| `setEngineName` / `setEngineSuffix` | cluster identity (enterprise feature) |

> `StartSequence`'s constructor runs a **binary-compatibility check** and can throw
> `Engine::RuntimeCompatibilityException` if the compiler version, debug/release
> mode, or engine version mismatch.

### 4.4 `Actor` — the unit of everything

Derive from it. Its constructor runs on its core's thread, and it is live
immediately.

**Identity and context**

| Method | Returns |
|---|---|
| `getActorId()` | this actor's `ActorId` — its address |
| `getCore()` | the `CoreId` it runs on |
| `getEngine()` | the `Engine` |
| `getServiceActorId<Tag>()` | shorthand for looking a service up by tag |
| `getAllocator()` | this core's local allocator |
| `getCorePerformanceCounters()` | loop counters (see §4.13) |
| `getEventLoop()` | the `EngineEventLoop` running it |

**Creating other actors** — all create on *this* actor's core:

| Method | Meaning |
|---|---|
| `newUnreferencedActor<A>()` → `const ActorId&` | fire and forget. You get an address, no ownership. |
| `newReferencedActor<A>()` → `ActorReference<A>` | you hold a smart reference; **direct method calls allowed** |
| `newReferencedSingletonActor<A>()` | one instance of `A` per core; subsequent calls return the same one |
| `referenceLocalActor<A>(actorId)` | take a reference to an actor that already exists on this core |

All of these throw `ShutdownException` during shutdown, and the referenced forms
throw `CircularReferenceException` if the reference would form a cycle.

**Handling events**

| Method | Meaning |
|---|---|
| `registerEventHandler<E>(handler)` | route `E` to `handler.onEvent(const E&)` |
| `registerUndeliveredEventHandler<E>(handler)` | route failed sends to `handler.onUndeliveredEvent(const E&)` |
| `unregisterEventHandler<E>()` | stop receiving `E` |
| `unregisterUndeliveredEventHandler<E>()` | stop receiving bounces of `E` |
| `unregisterAllEventHandlers()` | stop receiving everything |
| `isRegisteredEventHandler<E>()` | query |

> The handler need not be the actor itself, and **need not be polymorphic** —
> dispatch is resolved statically at registration through a function-pointer
> table (`StaticEventHandler`, `actor.h:3082`). This is why there is no `virtual
> onEvent`: it costs nothing and it lets one actor own several handler objects.
> Registering the same `<E, handler>` pair twice throws
> `AlreadyRegisterdEventHandlerException` (the misspelling is upstream's).

**Lifecycle**

| Method | Meaning |
|---|---|
| `requestDestroy()` | ask to be destroyed. Asynchronous — nothing happens yet |
| `onDestroyRequest()` (virtual) | called when eligible. Must call `acceptDestroy()` to confirm |
| `acceptDestroy()` (virtual) | confirm. Actual destruction happens at end of loop iteration |
| `onUnreachable(routeId)` (virtual) | a cluster route died (enterprise/e2e feature) |

**Callbacks** — see §4.9.

**Limits**: `MAX_NODE_COUNT = 255` cores, `MAX_EVENT_ID_COUNT = 4096` distinct
event classes at runtime (`actor.h:102-103`).

### 4.5 `ActorId` — the address

A value type you copy around freely. Internally (`actor.h:857+`) it is a
`NodeId` (which core) plus a `NodeActorId` (`uint64_t`, which actor on that core),
packed to 1 byte alignment.

```cpp
ActorId id;                        // default = invalid / null
if (id == Actor::ActorId()) { }    // comparable, orderable, streamable
```

- **`InProcessActorId`** — the same thing without cluster routing. Prefer it
  where possible; the docs say so explicitly (`actor.h:2107`).
- **`ActorId::RouteId` / `RouteIdComparable`** — cluster addressing across
  engines. Enterprise territory; ignore for CrashLab.

An `ActorId` for a dead actor is not dangling — it is simply undeliverable, and
sends to it bounce (§4.8). This is the key safety property of addressing by value
rather than by pointer.

### 4.6 `Actor::Event` — the message

```cpp
struct QuoteEvent : Actor::Event {
    QuoteEvent(int64_t px, uint32_t qty) : price(px), quantity(qty) {}
    int64_t  price;
    uint32_t quantity;
};
```

Any struct deriving `Actor::Event`. Constructed **in place** in the sender's event
page, never copied to send.

| Member | Meaning |
|---|---|
| `getSourceActorId()` | who sent it — how you reply |
| `getSourceInProcessActorId()` | cheaper form of the above, prefer it |
| `getDestinationActorId()` | who it was addressed to |
| `getClassId()` | the runtime `EventId` (a `uint16_t`) for this event class |
| `getName()` / `getContent()` | stream placeholders for logging |
| `static nameToOStream(os, e)` | you define this to name your event in logs |
| `static contentToOStream(os, e)` | you define this to dump its payload |

> ### ⚠ The rule that matters most
>
> **Event destructors are never run.** `~Event()` is empty and non-virtual
> (`actor.h:2254`); events are bump-allocated into a page and the page is
> recycled wholesale. Any owning member — `std::string`, `std::vector`,
> `unique_ptr` — **leaks, once per event sent.**
>
> This hides at small sizes. Tutorial 03 puts a `std::string` in its event and is
> Valgrind-clean, because `"Hello, World!"` is 13 characters and fits in
> libstdc++'s small-string buffer. Lengthen the literal past 15 characters and it
> becomes `172 bytes definitely lost in 2 blocks`.
>
> **Rule: events carry PODs only.** Scaled integers, fixed arrays, enums. Which is
> what the subject's scaled-integer requirement wants anyway.
>
> You cannot assert this on the event type — `Actor::Event` has a user-provided
> destructor, so `is_trivially_destructible_v<QuoteEvent>` is `false` by
> construction. Assert on the *members*:
> ```cpp
> static_assert(std::is_trivially_destructible_v<decltype(QuoteEvent::price)>);
> ```

### 4.7 `Actor::Event::Pipe` — the channel

A cheap, stack-allocated, **one-way** channel from one actor to one address.

```cpp
Event::Pipe pipe(*this, destinationActorId);
pipe.push<QuoteEvent>(10025, 7);          // constructs in place, sends
```

| Member | Meaning |
|---|---|
| `Pipe(sourceActor, destinationActorId)` | construct. Destination defaults to null |
| `push<E>(args...)` | construct an `E` from `args` in the event page and queue it |
| `setDestinationActorId(id)` | re-aim the same pipe |
| `getDestinationActorId()` / `getSourceActorId()` | query |
| `allocate<T>(n)` | raw array allocation in the event page |

Pipes are cheap enough to create per-message on the stack, which is what every
tutorial does. Keep one as a member only when the destination is fixed.

> **`push` does not perfect-forward.** The signature is
> `template<class _Event, class... _Args> _Event& push(_Args&&... args)` but the
> body passes `args...`, not `std::forward<_Args>(args)...` (`actor.h:2739`).
> Move semantics are silently lost. With POD-only payloads this costs nothing —
> another reason the POD rule is not a burden.

**`Event::BufferedPipe`** and **`Event::Batch`** are variants for accumulating
events; the plain `Pipe` is what you want.

### 4.8 Undelivered events — the built-in failure path

A send can fail. Simplx tells you, which is unusual and valuable. From
`actor.h:1590`, an event bounces in exactly three cases:

1. the destination actor does not exist (never did, or was destroyed);
2. it exists but never registered a handler for that event type;
3. its handler deliberately threw `ReturnToSenderException`.

```cpp
class SenderActor : public Actor {
public:
    SenderActor() {
        registerUndeliveredEventHandler<OrderEvent>(*this);
    }
    void onUndeliveredEvent(const OrderEvent &e) {
        // reject the order, tell the client, count the failure
    }
};
```

Case 3 is a real design tool, not just an error path: a receiver can accept an
event, inspect it, and *bounce it back* to say "not mine / can't do this" —

```cpp
void onEvent(const OrderEvent &e) {
    if (!canFill(e)) throw ReturnToSenderException();
}
```

For Exchange A this is how a `MatchingEngineActor` rejects an order without
inventing a `RejectEvent` type, and it is exactly what the subject's "gestion des
événements non livrés" requirement is asking about.

### 4.9 `Actor::Callback` — "run me again next iteration"

Not a timer. A callback registered with `registerCallback` is invoked **once**, on
the next loop iteration, then automatically unregistered. Re-register to keep
going. This is how you do polling or incremental background work without blocking.

```cpp
class MyActor : public Actor, public Actor::Callback {
public:
    MyActor() { registerCallback(*this); }
    void onCallback() {                 // called once, next iteration
        doOneChunkOfWork();
        if (moreToDo()) registerCallback(*this);   // re-arm
    }
};
```

You can derive the actor itself from `Callback` (as above) or hold separate
`Callback` members to get several distinct callbacks — that is what tutorial 05
demonstrates.

`registerPerformanceNeutralCallback()` does the same but is excluded from the
loop-usage performance counters. Use it for framework-ish bookkeeping you do not
want polluting your metrics.

| `Callback` member | Meaning |
|---|---|
| `isRegistered()` | is it armed? |
| `unregister()` | disarm; also called by `~Callback()` |

### 4.10 `Service` — naming actors so they can be found

```cpp
struct MatchingEngineTag : Service {};    // an empty type. That is the whole thing.
```

A service tag is a type used as a compile-time key. Register with
`addServiceActor<Tag, Actor>(core)`, look up anywhere with:

```cpp
const ActorId id = getEngine().getServiceIndex().getServiceActorId<MatchingEngineTag>();
```

This is the discovery mechanism: actors that need to talk to the matching engine
do not need a pointer to it, or to be constructed after it — they just need the
tag, which is a type, which is available everywhere.

`Service` itself (`internal/service.h:13`) is one static `name()` method. Tags must
be unique — a duplicate throws `StartSequence::DuplicateServiceException`.
`StartSequence::AnonymousService` is the escape hatch for "part of the service
lifecycle but not in the index".

### 4.11 `ActorReference<A>` — the smart pointer

When you need to call another actor's methods *directly* rather than message it —
only legal for actors on the same core.

```cpp
ActorReference<PrinterActor> ref = newReferencedActor<PrinterActor>();
ref->printMessage("direct call, no event", getActorId());   // synchronous!
```

It behaves like a reference-counted pointer: `operator*`, `operator->`, `get()`,
`reset()`, copyable. **When the last reference goes away, the referenced actor is
automatically destroyed** (`actor.h:229`).

Two guards:

- **`CircularReferenceException`** — Simplx walks the reference graph on every
  new reference and refuses to create a cycle, because a cycle would deadlock
  destruction. Not a warning, a thrown exception.
- **`ReferenceLocalActorException`** — you may not reference an actor on another
  core. Cross-core interaction is events, always.

For CrashLab: prefer events. Reach for `ActorReference` only for genuine
same-core ownership, where a synchronous call is both correct and measurably
cheaper — the subject's "no component may directly modify another's state" rule
means direct calls should be rare and deliberate.

### 4.12 Time — `Time` and `DateTime`

`Time` (`internal/time.h:28`) is a nanosecond count with helper constructors:

```cpp
Time::Second(1)  Time::Millisecond(200)  Time::Microsecond(50)  Time::Nanosecond(10)
```

`DateTime : Time` adds a broken-down UTC/local calendar view. Both predate
`std::chrono` and do not interoperate with it.

### 4.13 The timer

Three pieces:

| Piece | Role |
|---|---|
| `service::Timer` | the service tag |
| `timer::TimerActor` (= `TimerService`) | the service actor. Must be started explicitly |
| `timer::TimerProxy` | the mixin you inherit to *receive* timeouts |

```cpp
class FundingActor : public Actor, public timer::TimerProxy {
public:
    FundingActor() : TimerProxy(static_cast<Actor&>(*this)) {
        setRepeat(Time::Second(1));
    }
    void onTimeout(const DateTime &) noexcept override { chargeFunding(); }
};

// in main:
startSequence.addServiceActor<service::Timer, timer::TimerActor>(0);
```

| `TimerProxy` method | Meaning |
|---|---|
| `set(duration)` | fire once after `duration` |
| `setNow()` | fire as soon as possible |
| `setRepeat(duration)` | fire repeatedly |
| `unset()` / `stop()` | cancel |
| `isSet()` | query |
| `onTimeout(const DateTime&)` (virtual) | your handler |

> **⚠ The timer is wall-clock.** `TimerActor::onCallback()` calls `timeGetEpoch()`
> → `gettimeofday()` → `CLOCK_REALTIME`
> (`internal/linux/platform_gcc.h:268`). Not monotonic, not injectable, moves
> when NTP moves.
>
> **Nothing in a deterministic replay may be scheduled on this.** Funding ticks,
> liquidation sweeps and mark-price updates must be driven by simulated time.
>
> There is a seam: `TimerActor::onCallback()` is `virtual`, and the clock-taking
> overload `onCallback(const DateTime&)` is `protected`, commented *"protected for
> unit testing override"* (`timeractor.h:28,90`). Subclassing `TimerActor` to
> inject a clock is the intended route.

### 4.14 Exceptions

| Exception | Thrown when |
|---|---|
| `Actor::ShutdownException` | creating an actor during engine shutdown |
| `Actor::ReturnToSenderException` | *you* throw it, to bounce an event |
| `Actor::CircularReferenceException` | a reference would form a cycle |
| `Actor::UndersizedException` | > 4096 event classes, or > 4096 singleton actor types |
| `Actor::AlreadyRegisterdEventHandlerException` | double-registering a handler |
| `Actor::ReferenceLocalActorException` | referencing an actor on another core |
| `Engine::CoreInUseException` | starting a core that already has a loop |
| `Engine::UndersizedException` | the service index is full |
| `Engine::RuntimeCompatibilityException` | compiler/version/debug-mode mismatch |
| `Engine::CoreSet::TooManyCoresException` | more than 255 cores |
| `Engine::StartSequence::DuplicateServiceException` | two actors, one service tag |
| `FeatureNotImplementedException` | an enterprise-only feature in the open build |

An exception escaping `onEvent` does **not** kill the engine — it is routed to the
`AsyncExceptionHandler`, whose default implementation you can replace via
`StartSequence::setExceptionHandler()`. Treat anything arriving there as fatal;
the header says so explicitly.

### 4.15 Extension points and internals you will see but not use

| Name | What it is |
|---|---|
| `AsyncExceptionHandler` | override `onEventException()` to log/abort centrally |
| `EngineEventLoop` / `EngineCustomEventLoopFactory` | replace the spin loop itself |
| `EngineCustomCoreActorFactory` | customise the per-core housekeeping actor |
| `Actor::Allocator<T>` | STL-compatible allocator over the core-local pool |
| `Actor::string_type`, `property_type`, `ostringstream_type` | STL types using that allocator |
| `MultiDoubleChainLink` / `MultiForwardChainLink` | intrusive linked lists. Everything is one |
| `Property` | a small key/value tree |
| `CacheLineAlignedBufferContainer`, `CACHE_LINE_SIZE` | the cache-friendliness machinery |
| `EngineToEngineConnector`, `RouteId`, `TREDZONE_E2E` | cross-machine clustering. Enterprise; stubbed here |
| `service::E2ERoute` | its service tag |

`Actor::Allocator` is worth one note: allocating from the core-local pool avoids
`malloc` contention between cores. If an actor needs a `std::vector` member on the
hot path, `std::vector<T, Actor::Allocator<T>>` is the framework-native answer.
It is a member of the *actor*, never of an event.

---

## Part 5 — The modern C++ you meet here

You are coming from C++98. Simplx leans on a handful of post-98 features. These
are the ones you actually need to read its API:

| Feature | Where it shows up | What to know |
|---|---|---|
| **Variadic templates** (`_Args&&...`) | `push<E>(a, b, c)` | forwards constructor arguments so the event is built in place, not copied |
| **Tag types** | `struct PongTag : Service {}` | an empty type used as a compile-time key. Costs zero bytes |
| **`noexcept`** | everywhere | replaces `throw()`. **Since C++17 it is part of the function type** — that is what broke this build |
| **`override`** | `onTimeout(...) override` | compiler-checked "I am overriding". Use it always |
| **RAII smart pointers** | `ActorReference<A>` | destructor releases the reference; no manual `delete` |
| **Static polymorphism** | `registerEventHandler<E>(h)` | dispatch resolved at registration, not by vtable |

And the ones Simplx notably does *not* need, which you can defer learning:
`std::thread` and everything in `<mutex>`/`<atomic>`, `std::move` on the hot path
(POD events), `std::shared_ptr` (`ActorReference` does that job),
perfect forwarding (see §4.7).

Two idioms in the source that are *not* worth imitating: `throw()` exception
specifications (dated, and removed in C++20), and `// throws (std::bad_alloc,
ShutdownException)` written as comments rather than expressed in the type system.

---

## Part 6 — How this maps onto Exchange A

The subject mandates nine actors. With the vocabulary above, the shape is
already visible:

| Actor | Likely form |
|---|---|
| `GatewayActor` | owns client sessions; source of `NewOrderEvent`, sink of undelivered bounces |
| `MatchingEngineActor` | **service actor** — everyone needs to find it. Owns the book, single-threaded by construction |
| `AccountServiceActor` | **service actor** — balances and positions |
| `RiskActor` | pre-trade controls, consumes order + position events |
| `MarginActor` | margin computation |
| `LiquidationActor` | driven by a **simulated** clock, not `TimerProxy` |
| `MarketDataPublisherActor` | fan-out of L2/trade events |
| `MetricsActor` | consumes `getCorePerformanceCounters()` plus domain counters |
| `ScenarioControllerActor` | drives replay; probably the owner of simulated time |

The subject's rule — *"aucun composant ne doit modifier directement l'état d'un
autre"* — is the actor model's core invariant restated. Simplx enforces it for
you across cores; the one place you could break it is `ActorReference` direct
calls on the same core, so use them sparingly and deliberately.

Three constraints to design around from day one:

1. **Events are POD.** Scaled integers, fixed-size arrays, enums. No `std::string`
   in an event, ever — not even a short one.
2. **Do not schedule domain time on `TimerProxy`.** Funding, liquidation and
   mark-price ticks need a clock the replay controls.
3. **One core = 100% CPU.** This shapes how many cores you start, how CI runs
   tests, and — most sharply — how you benchmark. Measure a bounded batch of
   events, never a running engine's wall-clock throughput.

---

## Appendix — Where to look in the source

| Question | File |
|---|---|
| Everything about actors, events, pipes | `include/trz/engine/actor.h` (3.2k lines) |
| Engine, StartSequence, ServiceIndex | `include/trz/engine/engine.h` |
| The event loop and cross-core transport | `include/trz/engine/internal/node.h`, `src/engine/node.cpp` |
| `Time` / `DateTime` | `include/trz/engine/internal/time.h` |
| Timer | `include/trz/pattern/timer/` |
| The wall-clock call | `include/trz/engine/internal/linux/platform_gcc.h:268` |
| Worked examples | `tutorial/01`…`13`, each with its own README |

The tutorials in order: 01–02 (an actor, a callback), 03–04 (messaging, then
service discovery), 05 (callbacks), 06 (undelivered events), 07 (references vs
addresses), 08 (cross-core round trip), 09 (deterministic exit), 10 (timer),
11–13 (keyboard, TCP/HTTP, external-thread bridge).

Build them with `-DCMAKE_CXX_STANDARD=17` — **never** by passing `-std=c++17`
through `CMAKE_CXX_FLAGS`, which this build system silently ignores. See
`.scratch/learning-route/research/01-simplx-build-and-run.md`.
