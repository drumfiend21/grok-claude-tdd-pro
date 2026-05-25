# Architecture Principles

Authoritative reference for the architectural standards and rules that govern every change in this repo. Synthesized from the canonical sources in the industry on microservice design, loose coupling, and service autonomy.

This document is the binding rulebook. It complements (does not replace):

- `CLAUDE.md` — the prime directive (plugin-dependency model)
- `docs/architecture.md` — the harness-specific architecture (this repo's instance)
- `docs/handoff-contract.md` — the contract between this repo and `claude-tdd-pro`

If any architectural design or development work in this repo conflicts with a rule below, raise it before proceeding. The rules in §16 ("Synthesized rules this repo enforces") are the operational form — every change must satisfy them.

---

## How to use this document

1. **Before designing** a new component, contract, or integration: read §16 first; cross-reference the relevant authority section for the underlying principle.
2. **Before committing** code: run the self-audit checklist in §17. A change that fails any rule is out of contract.
3. **When a rule is in tension with a request**: defer to the rule. Surface the tension to the user. Do not silently relax a rule.
4. **When proposing a new rule or amending an existing one**: append a dated section at the bottom (see §19). Rules above are immutable in spirit — supersession is explicit, not in-place editing.

---

## §1. Lewis & Fowler — Nine Characteristics of Microservices [1]

The canonical 2014 definition. A microservice architecture is a particular way of designing software as a suite of independently deployable services. The nine characteristics are not all mandatory, but most microservice architectures exhibit most of them.

| # | Characteristic                              | Rule for this repo                                                                                                                    |
| - | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Componentization via services**           | Components are units of independent deployment. Use service boundaries, not in-process libraries, where independent evolution matters. |
| 2 | **Organized around business capabilities**  | Services are sliced by what they do for the business, not by technical layer (UI / DB / logic).                                       |
| 3 | **Products not projects**                   | The team owning a service owns it indefinitely — design, build, run, evolve. No throw-it-over-the-wall handoffs.                      |
| 4 | **Smart endpoints, dumb pipes**             | Logic lives in services. Pipes (HTTP, queues) carry messages and do not orchestrate or transform.                                     |
| 5 | **Decentralized governance**                | Each service may choose its own tech stack within agreed contracts. No central technology mandate beyond the contract surface.        |
| 6 | **Decentralized data management**           | Each service owns its data. No shared databases. Other services read data only through the owner's API.                               |
| 7 | **Infrastructure automation**               | Build, test, deploy, and observability are scripted. No manual environment setup.                                                     |
| 8 | **Design for failure**                      | Assume any dependency may fail. Every cross-service call has a defined failure mode, timeout, and fallback.                           |
| 9 | **Evolutionary design**                     | Architecture is refined through deliberate change, not big-bang rewrites. Contracts evolve through versioning, not breakage.          |

## §2. Sam Newman — Eight Principles of Microservices [2]

Newman's distilled discipline from *Building Microservices*. **Independent deployability is the single most important principle** — it forces loose coupling, well-defined contracts, and stable interfaces.

1. **Model around the business domain.** Use domain-driven design to find stable, reusable boundaries.
2. **Build a culture of automation.** Manual steps in build/deploy/test do not scale and break independent deployability.
3. **Hide implementation details.** Internal data stores, internal types, and internal technology choices are private to the service. Consumers see only the public contract.
4. **Embrace decentralization.** Push decisions to the team that owns the service. Centralized decision-making is a coupling vector.
5. **Deploy independently.** A service must be deployable without coordinated deploys of other services.
6. **Isolate failure.** A failure in one service must not cascade into others. Use timeouts, circuit breakers, bulkheads.
7. **Highly observable.** Every service emits structured logs, metrics, and traces. Cross-service correlation is built in.
8. **Consumer first.** Design the API from the consumer's perspective, not the provider's convenience.

## §3. Chris Richardson — Microservices Pattern Catalog [3]

The 44-pattern reference at microservices.io. Patterns this repo treats as load-bearing:

**Decomposition**
- **Decompose by Business Capability** — slice services along what the business does.
- **Decompose by Subdomain** — align with DDD bounded contexts (§7).

**Data**
- **Database per Service** — each service owns its persistence; no shared DB.
- **Saga** — manage cross-service transactions as a sequence of local transactions with compensating actions.
- **API Composition / CQRS** — query across services via composition or a separate read model, never via cross-service joins.

**Communication**
- **API Gateway** — single entry point for external clients; internal services are not directly addressable from outside.
- **Service Discovery** — clients resolve service addresses dynamically, not via hardcoded endpoints.
- **Asynchronous Messaging** — prefer events over synchronous calls for cross-service coordination; sync calls increase coupling.

**Reliability**
- **Circuit Breaker** — stop calling a failing dependency until it recovers.
- **Bulkhead** — isolate resource pools so one dependency's saturation does not starve the others.
- **Retry with Backoff + Idempotency** — every retried operation MUST be idempotent.

**Observability**
- **Log Aggregation, Distributed Tracing, Health Check API, Application Metrics** — non-optional. Without them, "design for failure" is theater.

**Deployment**
- **Service per Container / Immutable Server** — deploy artifacts are immutable; updates replace, not mutate.

## §4. CNCF — Cloud Native Definition [4]

Cloud-native systems are characterized by **loosely coupled systems that interoperate in a manner that is secure, resilient, manageable, sustainable, and observable**.

Typical building blocks: containers, service meshes, microservices, immutable infrastructure, declarative APIs, serverless.

Rules:

- Infrastructure is **immutable**. Servers are replaced, not mutated.
- APIs are **declarative**. Express intent (desired state) rather than imperative steps.
- Components are **loosely coupled** — independent evolution and deployment.
- Systems are designed for **observability** as a first-class concern, not an afterthought.

## §5. The Twelve-Factor App [5]

Heroku's 2011 methodology for portable, scalable SaaS-style services. Every microservice in this ecosystem MUST satisfy all twelve.

| Factor                  | Rule                                                                                                          |
| ----------------------- | ------------------------------------------------------------------------------------------------------------- |
| I. Codebase             | One codebase tracked in version control, many deploys. One repo per service.                                  |
| II. Dependencies        | Explicitly declare and isolate dependencies. Never rely on implicit system-wide packages.                     |
| III. Config             | Store config in the environment. Never hardcode environment-specific values.                                  |
| IV. Backing services    | Treat backing services (DBs, queues, third-party APIs) as attached resources, swappable by config.            |
| V. Build, release, run  | Strictly separate the three stages.                                                                           |
| VI. Processes           | Execute as one or more stateless processes. State lives in backing services.                                  |
| VII. Port binding       | Export services via port binding; the service is self-contained, no app server injection.                     |
| VIII. Concurrency       | Scale out via the process model, horizontally.                                                                |
| IX. Disposability       | Maximize robustness with fast startup and graceful shutdown.                                                  |
| X. Dev/prod parity      | Keep development, staging, and production as similar as possible.                                             |
| XI. Logs                | Treat logs as event streams. The service writes to stdout; the environment handles routing/storage.           |
| XII. Admin processes    | Run admin/management tasks as one-off processes in an identical environment.                                  |

## §6. The Reactive Manifesto — Four Traits [6]

A reactive system is **Responsive, Resilient, Elastic, and Message-Driven**. Message-driven is the foundation that enables the other three.

- **Responsive** — the system responds in a timely manner whenever possible. Responsiveness is the basis of usability and detects/handles failures fast.
- **Resilient** — stays responsive in the face of failure. Achieved through **replication, containment, isolation, and delegation**.
- **Elastic** — stays responsive under varying workload. Resources scale up and down with demand. No contended central bottleneck.
- **Message-Driven** — components communicate via **asynchronous message-passing**. This establishes a boundary that ensures **loose coupling, isolation, and location transparency**. Failures are delegated as messages.

Direct consequence: any cross-service interaction in this repo defaults to async messages. Synchronous request/response is a deliberate choice with stated justification.

## §7. Domain-Driven Design — Bounded Contexts [7]

Eric Evans' framework for structuring large systems around the domain.

- **Bounded Context** — a boundary inside which a particular domain model and ubiquitous language apply consistently. The same word can mean different things in different contexts, and that is OK as long as each context is internally consistent.
- **Ubiquitous Language** — within a bounded context, code, documentation, and domain-expert speech use the same terms with the same meanings.
- **Context Map** — explicit documentation of how bounded contexts relate (Partnership, Customer/Supplier, Conformist, Anti-Corruption Layer, Open Host Service, Published Language, Separate Ways).
- **Anti-Corruption Layer (ACL)** — a translation layer that protects a downstream context's model from upstream model changes. Mandatory whenever a service consumes a foreign model it does not own.

Rule: every service is a single bounded context (or a tight cluster of one root + its supporting contexts). Cross-context communication goes through translation, never through shared types.

## §8. Robert C. Martin — Component Coupling & Cohesion [8]

From *Clean Architecture*. The metrics that make "loose coupling" measurable.

**Cohesion (how to group things together):**
- **REP** — Reuse/Release Equivalence Principle: the granule of reuse is the granule of release.
- **CCP** — Common Closure Principle: classes that change together belong together.
- **CRP** — Common Reuse Principle: don't force consumers to depend on things they don't use.

**Coupling (how to relate components):**
- **ADP** — Acyclic Dependencies Principle: **the dependency graph must have no cycles**. Cycles are a coupling pathology.
- **SDP** — Stable Dependencies Principle: **depend in the direction of stability**. Less stable components depend on more stable ones, never the reverse.
- **SAP** — Stable Abstractions Principle: stable components should be abstract; volatile components should be concrete.

Stability is measured: a component's stability rises with incoming dependencies (others depend on it) and falls with outgoing dependencies (it depends on others). High-fan-in, low-fan-out components are stable and should be abstract.

## §9. Conway's Law & Team Topologies [9]

**Conway's Law** (Melvin Conway, 1968): organizations design systems that mirror their communication structure. If two teams must coordinate to ship one feature, the architecture will encode that coordination cost.

**Inverse Conway Maneuver**: design the team topology you want your architecture to reflect, then evolve the system to match. If you want loosely coupled services, give each service to a small, autonomous team with a clean interface; don't ask a single team to own two services that must change together.

**Team Topologies** (Skelton & Pais): four team types — **stream-aligned, platform, enabling, complicated-subsystem** — with three interaction modes — **collaboration, X-as-a-service, facilitating**. Each microservice has one owning team. Cross-team coupling = cross-service coupling.

## §10. Postel's Law & The Tolerant Reader [10]

**Postel's Law / Robustness Principle**: *Be conservative in what you do, be liberal in what you accept from others.*

**Tolerant Reader pattern** (Martin Fowler, 2011):
- Ignore unknown fields silently. Do not throw on schema additions.
- Use sensible defaults for missing optional fields.
- Extract only the fields actually used; do not bind the whole payload to a strict schema.
- Do not validate beyond what the consumer actually needs.

This is the practical mechanism that lets providers evolve independently of consumers without breaking them.

## §11. Consumer-Driven Contract Testing [11]

CDC (Pact, Pactflow): the consumer defines the interactions it expects from the provider; the provider runs those expectations as part of its CI; both sides know immediately when a contract is about to break.

Rules:
- Consumer expectations are stored as machine-readable contracts (e.g., Pact files), not English prose.
- The provider's CI verifies all current consumer contracts before merging any change.
- A provider change that breaks a consumer contract MUST either be reverted or coordinated with the consumer through an explicit deprecation.
- CDC reduces (but does not eliminate) the need for end-to-end tests; prefer CDC for contract correctness and reserve E2E for integration smoke.

## §12. API Versioning & Deprecation [12]

**Semantic Versioning (SemVer)** — `MAJOR.MINOR.PATCH`:
- **MAJOR** — breaking change. Consumers must update.
- **MINOR** — backward-compatible additions (new optional fields, new endpoints).
- **PATCH** — backward-compatible bug fixes.

Versioning placement:
- **URL versioning** (`/v1/...`) — clear, easy to route, good for major-version rewrites.
- **Header versioning** — keeps URLs clean, good for incremental feature toggles.

Hybrid (URL for major rewrites + headers for fine-grained toggles) is acceptable. Choose one and document it; do not mix arbitrarily.

**Deprecation policy** (mandatory):
- A deprecated version is announced with a sunset date no sooner than N (default: two release cycles) in the future.
- Migration guides ship with the deprecation notice.
- Old versions continue to function until sunset; sunset is enforced via a hard cutover, not silent breakage.

## §13. AWS Well-Architected — Loose Coupling & EDA [13]

From `REL04-BP02: Implement loosely coupled dependencies` and the AWS event-driven architecture guidance:

- Prefer **asynchronous, event-driven communication** over synchronous request/response for cross-service workflows. Event producers and consumers evolve independently.
- Insert an **intermediate layer** (queue, event bus, stream) between any two services that would otherwise be tightly coupled. The intermediate layer becomes the contract surface.
- Every operation MUST be **idempotent and transactional**. Retries are inevitable; non-idempotent operations corrupt state.
- For multi-service transactions, use the **Saga pattern** with compensating transactions, not distributed two-phase commit.
- Choreography (event-driven, decentralized) is preferred for simple workflows; orchestration (centralized coordinator) is acceptable for complex workflows but introduces a single point of coordination.

## §14. Information Hiding & Service Autonomy

Cross-cutting from §1, §2, §6, §7: a service's autonomy is exactly equal to how much of its internals it hides.

Rules:
- A service's database is private. No other service may read or write to it directly.
- A service's internal types, internal event names, internal storage layout are private.
- The public contract is: (a) the API (sync or async), (b) the published event schemas, (c) the operational SLO. Nothing else.
- If a consumer needs a field that is not in the public contract, the right answer is to extend the public contract, not to reach into the internal model.

## §15. Architecture Decision Records (ADRs) [14]

Every architecturally significant decision in this repo is captured as a Michael Nygard-format ADR.

- Location: `docs/adr/NNNN-<title>.md`. Numbers sequential, monotonic, never reused.
- Format: **Title, Status, Context, Decision, Consequences**.
- Status lifecycle: **Proposed → Accepted → Deprecated / Superseded**.
- **Accepted records are immutable.** Corrections happen by writing a new ADR that supersedes the old one and updating the old one's status to `Superseded by ADR-NNNN`.
- An ADR is "architecturally significant" if it (a) changes the contract surface with another repo/service, (b) introduces or removes a dependency, (c) changes a rule in this document, or (d) chooses between two options where future changes would be costly.

---

## §16. Synthesized rules this repo enforces

These are the operational rules. Every change is checked against this list. The number after each rule cites the authority section above.

| Rule  | Statement                                                                                                                                                  | Source |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| R-1   | No cross-repo edits. A change in this repo MUST NOT require an edit inside `claude-tdd-pro`.                                                               | §1, §2 |
| R-2   | The plugin (`claude-tdd-pro`) is imported by reference (pinned version), never vendored, copied, or forked into this tree.                                 | §1.6, §5.II |
| R-3   | The only coupling surface with the plugin is the handoff contract (`docs/handoff-contract.md`) and named skill IDs. Internal paths of the plugin are off-limits. | §2.3, §14 |
| R-4   | Independent release cadence. This repo MUST be releasable without a synchronized release of `claude-tdd-pro`, except when bumping the contract `schema_version`. | §2.5  |
| R-5   | Contract changes are bilateral and explicit. Bump `schema_version`; ship two coordinated PRs; never silently change wire formats.                          | §12   |
| R-6   | Each component (service, skill, contract) is sliced along a business capability or DDD bounded context, never along a technical layer.                     | §1.2, §3, §7 |
| R-7   | Information hiding is mandatory. Public contract = API + published events + SLO. Everything else is private.                                               | §2.3, §14 |
| R-8   | No shared databases or shared mutable state across services. Reads happen via the owner's API.                                                              | §1.6, §3 |
| R-9   | Cross-service interaction defaults to **asynchronous messaging**. Synchronous calls require stated justification.                                          | §6, §13 |
| R-10  | Every retried operation is **idempotent**. Every cross-service call has a defined timeout, retry policy, and failure mode.                                 | §1.8, §13 |
| R-11  | Consumers practice **tolerant reading**: ignore unknown fields, default missing optional fields, extract only what is used.                                | §10   |
| R-12  | Providers preserve **backward compatibility within a major version**. Breaking changes require a new MAJOR and a deprecation period.                       | §12   |
| R-13  | New consumer expectations are captured as **CDC contracts** the provider's CI verifies. No silent contract drift.                                          | §11   |
| R-14  | The **dependency graph is acyclic**. Components depend in the direction of stability (SDP); abstractions sit at the stable end (SAP).                      | §8    |
| R-15  | **No central technology mandate** beyond what the contract requires. A service may pick its own internal stack.                                            | §1.5  |
| R-16  | **One owning team per service.** Cross-team coordination cost is treated as architectural debt to be removed.                                              | §9    |
| R-17  | Every service satisfies all **twelve factors** (codebase, dependencies, config, backing services, build/release/run, processes, port binding, concurrency, disposability, dev/prod parity, logs, admin). | §5 |
| R-18  | Infrastructure is **immutable**. Deploys replace artifacts; they do not mutate live ones.                                                                  | §4    |
| R-19  | **Observability is a first-class concern.** Structured logs, metrics, and distributed traces ship with every service from day one, not retrofitted.        | §2.7, §3 |
| R-20  | Every architecturally significant decision is captured as an **ADR** in `docs/adr/`. Accepted ADRs are immutable; supersession is explicit.                | §15   |

---

## §17. Self-audit checklist (run before every commit / PR / handoff)

A change is in contract if every answer is YES.

- [ ] Does this change preserve the plugin-dependency invariant? (R-1 .. R-5)
- [ ] Are service boundaries aligned to a business capability or bounded context? (R-6)
- [ ] Is all new state owned by a single service, and not accessed by others except through its API? (R-7, R-8)
- [ ] Are new cross-service interactions asynchronous unless there is a stated reason otherwise? (R-9)
- [ ] Are new operations idempotent, and do they have timeouts + retry policy + failure mode? (R-10)
- [ ] Do new consumers tolerate unknown / missing fields? (R-11)
- [ ] If this change touches a public contract, is it backward-compatible within the major version, or paired with a MAJOR bump + deprecation plan? (R-12)
- [ ] Are new consumer expectations encoded as CDC contracts that the provider's CI runs? (R-13)
- [ ] Does the change introduce a dependency cycle, or depend from a stable component on a less stable one? (R-14) — if YES, reject.
- [ ] Does the change preserve independent deployability? (R-4)
- [ ] Are the twelve factors satisfied? (R-17)
- [ ] Are logs / metrics / traces added for new code paths? (R-19)
- [ ] Is the decision captured as an ADR if it is architecturally significant? (R-20)

---

## §18. Authoritative sources

[1] Lewis, J. & Fowler, M. (2014). *Microservices: a definition of this new architectural term.* https://martinfowler.com/articles/microservices.html
[2] Newman, S. (2021). *Building Microservices, 2nd Edition.* O'Reilly. https://samnewman.io/books/building_microservices_2nd_edition/
[3] Richardson, C. *Microservices Pattern Catalog.* https://microservices.io/patterns/
[4] CNCF Technical Oversight Committee. *CNCF Cloud Native Definition v1.1.* https://github.com/cncf/toc/blob/main/DEFINITION.md
[5] Wiggins, A. (2011, rev. 2017). *The Twelve-Factor App.* https://12factor.net/
[6] Bonér, J. et al. (2014). *The Reactive Manifesto v2.0.* https://www.reactivemanifesto.org/
[7] Evans, E. (2003). *Domain-Driven Design: Tackling Complexity in the Heart of Software.* Addison-Wesley. See also Fowler, M. *bliki: BoundedContext.* https://martinfowler.com/bliki/BoundedContext.html
[8] Martin, R. C. (2017). *Clean Architecture: A Craftsman's Guide to Software Structure and Design.* Prentice Hall. (Component Cohesion: REP/CCP/CRP; Component Coupling: ADP/SDP/SAP.)
[9] Skelton, M. & Pais, M. (2019). *Team Topologies.* IT Revolution Press. See also Fowler, M. *bliki: ConwaysLaw.* https://martinfowler.com/bliki/ConwaysLaw.html
[10] Fowler, M. (2011). *Tolerant Reader.* https://martinfowler.com/bliki/TolerantReader.html (and Jon Postel, RFC 761/793, Robustness Principle.)
[11] Robinson, I. (2006). *Consumer-Driven Contracts: A Service Evolution Pattern.* Pact / Pactflow: https://pactflow.io/what-is-consumer-driven-contract-testing/
[12] Preston-Werner, T. *Semantic Versioning 2.0.0.* https://semver.org/  · API versioning practice synthesized from Zuplo, Microservice API Patterns. https://microservice-api-patterns.org/patterns/evolution/SemanticVersioning
[13] AWS. *Well-Architected Framework — REL04-BP02: Implement loosely coupled dependencies.* https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_prevent_interaction_failure_loosely_coupled_system.html  · *Implementing Microservices on AWS (Whitepaper).* https://docs.aws.amazon.com/pdfs/whitepapers/latest/microservices-on-aws/microservices-on-aws.pdf
[14] Nygard, M. (2011). *Documenting Architecture Decisions.* https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions  · ADR templates: https://adr.github.io/

---

## §19. Amendments

Rules above are immutable in spirit. To revise a rule:

1. Open an ADR in `docs/adr/` that proposes the change, in Nygard format, with status `Proposed`.
2. On acceptance, append an entry to this section noting the date, the ADR ID, and the rules amended.
3. Update the affected rule rows in §16 in the same commit, with a footnote pointing to the ADR.
4. Do not delete prior rule text; if a rule is superseded, mark it `Superseded by ADR-NNNN` rather than removing it.

*(No amendments yet.)*
