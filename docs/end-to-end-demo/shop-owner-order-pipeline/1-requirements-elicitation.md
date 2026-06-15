# Phase 1 — Requirements elicitation

**Goal:** turn one plain sentence into the handful of technical parameters that actually
decide the architecture — *without* asking Aisha anything she cannot answer.

The outer loop asks in **small clusters**, never a wall of questions. Each question is
tagged (for our benefit, not hers) with the parameter it resolves.

---

**Intake — the plain request**

> 🧑‍🌾 **Aisha:** *"My online shop is growing and sometimes orders get dropped during
> busy sales. I need order processing that never loses an order and works for customers
> in different countries."*

---

**Round 1 — Scale & the pain**

> 🤖 **Harness:** A couple of quick ones so I size this right, no tech knowledge needed:
> 1. On a normal day, roughly how many orders? And on your *busiest* sale hour?
> 2. When an order "gets dropped" today — does the customer get charged but you never see
>    the order, or do they just get an error and give up?

> 🧑‍🌾 **Aisha:** Normal day maybe 200 orders. During a big sale I've seen 600–700 in an
> hour, in bursts. And yes — the scary one happened twice: the customer was charged but
> the order never showed in my dashboard.

```
[param] peak ≈ 700/hr, bursty → ~3–5 orders/sec spikes, not sustained high throughput
[param] failure class = "charged-but-lost" → durability + exactly-once EFFECT is the
        core requirement, not raw scale
```

**Round 2 — Geography**

> 🤖 **Harness:** "Different countries" can mean a few things. Where are your customers,
> and is anyone telling you their data has to *stay* in their country (for example, EU
> customers)?

> 🧑‍🌾 **Aisha:** Mostly US and Europe, a growing bit in Australia. I had a customer in
> Germany ask once whether their details "stay in Europe." I didn't know what to say.

```
[param] regions = US + EU + AU; EU data-residency is a real constraint (GDPR)
        → regional processing, not just a single global box
```

**Round 3 — Who operates it**

> 🤖 **Harness:** Last cluster. Do you (or anyone you pay) babysit servers today, or do
> you want this to mostly run itself? And what's the shop built on now — Shopify,
> something custom, not sure?

> 🧑‍🌾 **Aisha:** It runs itself, I have no one technical. It's a custom site a freelancer
> built — I think it's "Node" something? I honestly don't know.

```
[param] ops budget ≈ 0 engineers → managed / serverless bias (lowest operational surface)
[param] existing stack = Node.js / TypeScript → aligns with the node + typescript
        standard namespaces
```

---

## What Phase 1 produced

Five parameters — and nothing Aisha couldn't answer:

| Parameter | Value | Why it matters downstream |
|---|---|---|
| Peak load | ~700/hr, bursty | Favors a queue + backpressure, not a big always-on cluster |
| Failure class | "charged-but-lost" | Makes **durability + exactly-once effect** the central design driver |
| Regions | US + EU + AU, EU residency | Forces **regional** processing & storage, not a single global box |
| Ops capacity | ~0 engineers | **Managed / serverless** bias |
| Stack | Node.js / TypeScript | Selects the `node` + `typescript` standard namespaces |

Next: **[Phase 2 — Guided technical decisions](2-guided-technical-decisions.md)** →

← [Flow overview](README.md) · [Demonstration index](../README.md)
