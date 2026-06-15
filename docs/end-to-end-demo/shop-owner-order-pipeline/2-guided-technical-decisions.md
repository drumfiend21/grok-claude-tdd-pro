# Phase 2 — Guided technical decisions

**Goal:** for each *genuine* fork in the design, the harness explains the trade-off in
Aisha's terms, **recommends**, and records her choice — then attaches the world-class
defaults she could never request, *explaining them anyway*.

Jargon is defined inline or avoided. Options are surfaced one fork at a time.

---

## Decision 1 — How do we guarantee "never lose an order, never double-charge"?

> 🤖 **Harness:** There are two honest ways to do this:
> - **(A) "Try until it sticks," with a memory of what's already done.** Every order gets
>   a unique ticket number; if the system retries after a hiccup, it sees "already handled
>   ticket #4471" and skips it. Simple, battle-tested, cheap.
> - **(B) "Mathematically exactly once."** Sounds nicer, but in the real world it's fragile
>   and expensive — it tends to *create* the stuck-order problem you're trying to kill.
>
> I recommend **(A)**. You get your guarantee — no lost orders, no double-charges — without
> the fragility. The jargon for it is *idempotency*; you don't need to remember that.

> 🧑‍🌾 **Aisha:** Option A. I just want it to be reliable.

```
[decision] at-least-once delivery + idempotency keys (per-order dedup)
           → satisfies the "exactly-once EFFECT"
[standard] g-node-007 (transaction boundaries) — the "mark order accepted" write is one
           atomic step so a crash can't half-write it
```

## Decision 2 — Accept the order *first*, do the slow work *after*?

> 🤖 **Harness:** The "charged-but-lost" bug usually happens because the site tries to do
> *everything* in one breath — take the order, charge, email, update stock — and if any
> step trips, the whole thing falls over.
> I'd split it: the instant an order is placed, we **write it down somewhere permanent and
> tell the customer "got it"** in well under a second. Then payment, stock, and email happen
> **right after, on their own**, retrying safely if needed. The order can never be lost
> because it was recorded *before* any of the risky steps.

> 🧑‍🌾 **Aisha:** Yes — recording it first is exactly what I want.

```
[decision] durable-accept-then-process (write-ahead) + asynchronous pipeline
[decision] managed queue between accept and process (absorbs the 700/hr bursts)
[standard] g-node-006 (stream backpressure) + g-node-003 (timeouts & retry) — bursts queue
           up instead of overwhelming the workers
```

## Decision 3 — Where does it run, and where does data live?

> 🤖 **Harness:** For your situation — no ops team — I'd use **managed, serverless building
> blocks** (you don't patch or babysit anything) deployed in **three regions: US, EU,
> Australia.** Orders are handled in the region closest to the customer, and crucially
> **EU orders are processed and stored in the EU**, so you can answer that German customer
> honestly: "yes, your details stay in Europe."

> 🧑‍🌾 **Aisha:** That's a huge relief. Do it that way.

```
[decision] active-active multi-region (geo-routed ingest), regional processing + storage
[decision] EU data residency enforced by routing EU orders to the EU stack only
```

## Decision 4 — What happens when something genuinely won't go through?

> 🤖 **Harness:** Some orders will hit a real snag (a card declines, a supplier API is
> down). I'll retry a few times automatically. If it still won't go, instead of silently
> dropping it, I'll **park it in a "needs attention" tray and ping you.** Nothing
> disappears; the worst case is "Aisha, 1 order needs a look," not a lost sale.

> 🧑‍🌾 **Aisha:** Please. I'd much rather be told than lose it.

```
[decision] bounded retry → Dead-Letter Queue ("needs-attention tray") → operator alert
[standard] g-node-002 (typed error taxonomy) + g-node-004 (structured logging) — failures
           are categorized & searchable, not console noise
```

---

## Decisions she never had to make (world-class defaults, explained anyway)

The harness attaches these because they protect Aisha and she'd have no way to know to
ask. It still tells her, in one breath each:

> 🤖 **Harness:** Three things I'm including without asking:
> - **Every incoming order is checked for being well-formed before it's allowed in** — a
>   garbled order from a flaky phone connection can't corrupt your pipeline.
>   *(OWASP boundary validation — `g-node-001`; `g-node-008` keeps your payment keys out of
>   the code.)*
> - **Every third-party building block we use is cryptographically verified** before it
>   ships — so the system you trust with real orders is itself trustworthy and can't be
>   tampered with in transit. *(SLSA build provenance — `g-node-010`; the one most shops skip.)*
> - **The order's life-cycle is modeled so the computer is forced to handle every state** —
>   "received, paid, shipped, refunded…" — and the build literally won't compile if a new
>   state is left unhandled. *(`g-ts-003` exhaustive state machine, `g-ts-006` strict TypeScript.)*

```
[critical] slsa namespace (g-node-010) — the standard Aisha could never name; non-negotiable
           for a system handling money and orders. This is the scenario's critical_namespace.
```

Next: **[Phase 3 — Architecture synthesis](3-architecture-synthesis.md)** →

← [Phase 1](1-requirements-elicitation.md) · [Flow overview](README.md) · [Demonstration index](../README.md)
