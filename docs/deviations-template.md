# `docs/deviations.md` row template

Copy this template into the app tree as `<app_root>/docs/deviations.md` and add one
section per legitimate deviation. The design-phase MD gate
(`scripts/audit-design-phase-md.sh`, ADR-0066 D-D) treats a rule as `deviated` (green-equivalent)
when a `## Deviation — <RULE-ID> on <TICKET-ID>` heading is present in this file.

Every row records: rule, scope, why the rule cannot apply in this context, an explicit
operator acceptance, and a re-eval condition. Deviations are visible scoping, never
silent exclusion. Per the operator directive on ADR-0066: "don't exclude anything."

A deviation applies to a single ticket. Cross-ticket deviation requires a separate row or
an ADR-blessed standing exception.

---

# Deviations

<!--
COPYABLE TEMPLATE (one block per deviation):

## Deviation — <RULE-ID> on <TICKET-ID>

- **Rule:** `<rule-id>` (severity, source_namespace)
- **Scope:** <ticket-id>, file_scope `<glob-or-path>`
- **Why-cannot-apply:** <one-paragraph rationale. Cite the ADR that locks the cloud /
  framework / scope choice (e.g., ADR-0010 declares AWS-only; the rule's Azure surface
  has no target).>
- **Operator acceptance:** <operator-email> on YYYY-MM-DD
- **Re-eval condition:** <one-line trigger that reopens this deviation — e.g.,
  "revisit when ADR-0010 is amended or new clouds enter the architecture.">
-->

## Deviation — g-azure-encrypt-at-rest on TICKET-EXAMPLE

- **Rule:** `g-azure-encrypt-at-rest` (P0, source_namespace: azure)
- **Scope:** TICKET-EXAMPLE, file_scope `infra/**/*.tf`
- **Why-cannot-apply:** the project is AWS-only per `docs/architecture/adr/0010-data-residency-region-extensible-iac.md`; no Azure resources exist in the tree.
- **Operator acceptance:** operator@example.com on 2026-06-19
- **Re-eval condition:** revisit when ADR-0010 is amended or new clouds enter the architecture.

## Deviation — g-aws-no-unrestricted-ingress on TICKET-DEV-CLUSTER

- **Rule:** `g-aws-no-unrestricted-ingress` (P0, source_namespace: aws)
- **Scope:** TICKET-DEV-CLUSTER, dev-cluster network design
- **Why-cannot-apply:** the dev cluster is provisioned inside an isolated VPC with no Internet Gateway; the `0.0.0.0/0` reference in ADR-0015 is intra-VPC only. The rule's network-exposure premise does not hold.
- **Operator acceptance:** operator@example.com on 2026-06-19
- **Re-eval condition:** revisit if the dev cluster ever gains an IGW or NAT route, or if ADR-0015 is amended to permit broader connectivity.

---

## Notes on use

- The heading must match the regex `^## Deviation — <RULE-ID> on <TICKET-ID>$`. The em-dash (`—`) and the regular hyphen (`-`) are both tolerated by the gate's matcher.
- The body fields below the heading are operator-facing documentation; the gate does not parse them but reviewers (and future-you) will.
- When a rule's deviation is no longer needed (because the rule's domain genuinely changed, or the code was rewritten), strike-through the heading with `<del>...</del>` to preserve the audit trail.
- Deviations are not a substitute for fixing the rule violation — they are an operator-acknowledged carve-out. The gate's purpose is to make sure the carve-out is deliberate and recorded.
