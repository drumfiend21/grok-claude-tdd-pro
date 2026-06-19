# Standards sources — Markdown corpus (two-layer)

Stable in-repo mirror of the 40-source MD standards bundle (Layer 1 syntactic + Layer 2 prose-as-code) assembled in the 2026-06-19 GCTP research session. Cited by `docs/adr/0066-yaml-json-md-corpora-and-prose-as-code-enforcement.md` and by `proposals/PROPOSAL-003-ctp-session-brief.md`.

**The two-layer principle:**
- **Layer 1 (syntactic)** — markdownlint / CommonMark / GFM / Vale / link-check / spell-check / frontmatter shape / license-headers. Mechanical rules; off-the-shelf CLIs; no LLM cost.
- **Layer 2 (prose-as-code, semantic)** — ADR/arc42/C4 templates as structural rules PLUS the semantic projection of every code rule in `active.json` onto architectural prose. Requires LLM-judge.

**License posture summary:**
- **Mirror permitted**: Apache 2.0, MIT, CC-BY-4.0, CC-BY-SA-4.0, BSD-3-Clause, ISC, CC0, IETF RFC public.
- **Cite-link only**: ISO/IEC/IEEE 42010 (paywalled), Microsoft Writing Style Guide (proprietary, linkable).
- **GPL config/grammar only (no detector code)**: codespell (GPL-2.0; dicts CC-BY-SA-3.0).

## Layer 1 — Structural / syntactic rules (21 sources)

| # | Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|---|
| 1 | CommonMark 0.31.2 | John MacFarlane | https://spec.commonmark.org/0.31.2/ + repo raw `spec.txt` | HTML / RAW | CC-BY-SA 4.0 |
| 2 | GitHub Flavored Markdown | GitHub | https://github.github.com/gfm/ | HTML | CC-BY-SA 4.0 |
| 3 | markdownlint rules MD001..MD060 | David Anson | https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md | RAW MD | MIT |
| 4 | remark-lint (unified) | unified collective | https://github.com/remarkjs/remark-lint | RAW MD | MIT |
| 5 | Vale (prose-linter engine) | jdkato | https://vale.sh + repo | RAW + HTML | MIT |
| 6 | Vale styles hub | errata-ai | https://github.com/errata-ai (Google / Microsoft / write-good / alex / proselint forks) | RAW YAML | mixed per package |
| 7 | alex (inclusive language) | get-alex/alex | https://github.com/get-alex/alex | RAW | MIT |
| 8 | write-good | btford/write-good | https://github.com/btford/write-good | RAW | MIT |
| 9 | proselint | amperser/proselint | https://github.com/amperser/proselint | RAW | BSD-3-Clause |
| 10 | textlint | textlint | https://github.com/textlint/textlint | RAW | MIT |
| 11 | retext (equality / profanities / simplify / passive) | retextjs | https://github.com/retextjs | RAW | MIT |
| 12 | markdown-link-check | tcort | https://github.com/tcort/markdown-link-check | RAW | ISC |
| 13 | lychee link checker | lycheeverse | https://github.com/lycheeverse/lychee | RAW | Apache-2.0 OR MIT |
| 14 | Hugo front matter | Hugo | https://gohugo.io/content-management/front-matter/ | HTML | Apache-2.0 (docs) |
| 15 | Jekyll front matter | Jekyll | https://jekyllrb.com/docs/front-matter/ | HTML | MIT |
| 16 | Docusaurus markdown features | Meta | https://docusaurus.io/docs/markdown-features | HTML | MIT |
| 17 | Mermaid spec | mermaid-js | https://mermaid.js.org/intro/ | HTML + RAW | MIT |
| 18 | PlantUML | PlantUML | https://plantuml.com/ | HTML | GPL engine / docs CC |
| 19 | REUSE 3.3 spec (SPDX headers) | FSFE | https://reuse.software/spec-3.3/ | HTML | CC-BY-SA 4.0 |
| 20 | cspell | streetsidesoftware | https://github.com/streetsidesoftware/cspell | RAW | MIT |
| 21 | codespell | codespell-project | https://github.com/codespell-project/codespell | RAW | GPL-2.0 (dicts CC-BY-SA-3.0) |

## Layer 2 — Semantic / prose-as-code rules (19 sources)

| # | Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|---|
| 22 | RFC 2119 (keyword authority) | IETF | https://www.rfc-editor.org/rfc/rfc2119 | HTML / TXT | IETF Trust |
| 23 | RFC 8174 (case-sensitivity clarification) | IETF | https://www.rfc-editor.org/rfc/rfc8174 | HTML / TXT | IETF Trust |
| 24 | MADR 4.0 ADR template | adr/madr | https://adr.github.io/madr/ + repo raw | HTML / RAW | MIT OR CC0-1.0 |
| 25 | ADR template catalog (Nygard / Y-Statements / Planguage / Alexandrian) | joelparkerhenderson | https://github.com/joelparkerhenderson/architecture-decision-record | RAW | MIT |
| 26 | Y-Statements | Olaf Zimmermann | https://medium.com/olzzio/y-statements-10eb07b5a177 (mirror in catalog above) | HTML | CC-BY (article) |
| 27 | arc42 (12-section template) | Hruschka + Starke | https://arc42.org/overview + GitHub templates | HTML / RAW | CC-BY-SA 4.0 |
| 28 | C4 model | Simon Brown | https://c4model.com/ | HTML | CC-BY 4.0 |
| 29 | ISO/IEC/IEEE 42010:2022 | ISO | https://www.iso.org/standard/74393.html | PAYWALL | proprietary — use arc42 + C4 surrogates |
| 30 | Diátaxis framework | Daniele Procida | https://diataxis.fr/ | HTML | CC-BY-SA 4.0 |
| 31 | Write the Docs guide | community | https://www.writethedocs.org/guide/ | HTML | CC-BY 4.0 |
| 32 | Google developer docs style guide | Google | https://developers.google.com/style | HTML | CC-BY 4.0 |
| 33 | Microsoft Writing Style Guide | Microsoft | https://learn.microsoft.com/en-us/style-guide/welcome/ + MicrosoftDocs/microsoft-style-guide-pr | HTML / RAW | proprietary but linkable |
| 34 | standard-readme spec | Richard Littauer | https://github.com/RichardLitt/standard-readme | RAW | MIT |
| 35 | Make a README | Danny Guo | https://www.makeareadme.com/ | HTML | MIT |
| 36 | GitHub open-source-guide | GitHub | https://opensource.guide/ + github/opensource.guide | HTML / RAW | CC-BY 4.0 |
| 37 | Conventional Commits 1.0.0 | OpenJS | https://www.conventionalcommits.org/en/v1.0.0/ | HTML | CC-BY 3.0 |
| 38 | Keep a Changelog 1.1.0 | Olivier Lacan | https://keepachangelog.com/en/1.1.0/ | HTML | MIT |
| 39 | SemVer 2.0.0 | Tom Preston-Werner | https://semver.org/spec/v2.0.0.html | HTML | CC-BY 3.0 |
| 40 | Contributor Covenant 2.1 | Org. for Ethical Source | https://www.contributor-covenant.org/version/2/1/code_of_conduct/ | HTML + RAW | CC-BY 4.0 |
| 41 | OWASP STRIDE (threat modeling) | OWASP | https://owasp.org/www-community/Threat_Modeling_Process | HTML | CC-BY-SA 4.0 |
| 42 | LINDDUN (privacy threat modeling) | KU Leuven DistriNet | https://www.linddun.org/ | HTML | CC-BY (educational) |
| 43 | GitHub Advisory Database (OSV) | GitHub | https://github.com/github/advisory-database | RAW | CC-BY 4.0 |

## Highest-leverage seeds (start order)

**Layer 1:**
1. **markdownlint Rules.md** (#3) — MIT, MD001..MD060 reference. Drop-in CLI; SARIF-emitting; MD040 + MD043 are the workhorse rules (code-fence language + required-headings).
2. **Vale + errata-ai style packs** (#5, #6) — single orchestrator for Google / Microsoft / alex / write-good / proselint; SARIF-native.
3. **lychee** (#13) link-check; **cspell** (#20) + **codespell** (#21) spell; **REUSE 3.3** (#19) license-header.

**Layer 2:**
1. **MADR 4.0** (#24) — MIT/CC0 default ADR template; YAML frontmatter checkable via JSON Schema.
2. **arc42** (#27) — CC-BY-SA-4.0; 12 numbered sections; mechanically enforceable via markdownlint MD043.
3. **C4 model** (#28) — CC-BY-4.0; element vocabulary discipline (Person / Software System / Container / Component).
4. **RFC 2119 + RFC 8174** (#22, #23) — IETF public; regex-enforce the BCP 14 invocation sentence whenever uppercase MUST/SHOULD/MAY appears.
5. **Diátaxis** (#30) — CC-BY-SA-4.0; classifier for tutorial / how-to / reference / explanation modes.

## The semantic-projection corpus (Layer 2 secondary)

Beyond the doc-shape and prose-style rules above, Layer 2's defining principle is that **every code rule in `active.json` with `applies_to_prose: true`** also fires on architectural MD. The Layer 2 source list above provides the rule SHAPE; the rule CONTENT is projected dynamically from the existing namespaces (`aws`, `azure`, `gcp`, `hashicorp`, `owasp`, `slsa`, `security-governance`, `iam`, `jwt`, etc.) via the `prose-judge.sh` detector in CTP.

## Excluded / superseded

- **AsciiDoc** — different format; out of scope.
- **reStructuredText** — out of scope unless a project converts.
- **Datree** — archived; superseded by markdownlint + Vale.

## Duplicates and pick-upstream

| Concern | Tools | Pick |
|---|---|---|
| Inclusive language | alex, errata-ai/alex (Vale), retext-equality, proselint social_awareness | **alex** as engine; Vale `errata-ai/alex` for SARIF cohabitation |
| Prose lint | Vale, write-good, proselint, textlint | **Vale** as orchestrator (imports Google + MS + write-good + alex + proselint) |
| Spell-check | cspell, codespell, Vale spelling | **cspell** code-aware + **codespell** lightweight; both, not either |
| Link-check | markdown-link-check, lychee | **lychee** primary (fast Rust); markdown-link-check fallback |
| MD syntax | markdownlint, remark-lint | **markdownlint** primary (SARIF + MD-rule-numbering); **remark-lint** for AST-precise rules |
| ADR template | Nygard, MADR, Y-Statements | **MADR 4.0** default; Y-Statements inline; Nygard for legacy |
| Architecture-doc shape | arc42, IEEE 42010 | **arc42** (free, 12 sections, MD043-enforceable); IEEE 42010 conceptual cite only |
| Doc taxonomy | Diátaxis, Write the Docs | **Diátaxis** classifier; Write the Docs for community conventions |
| Style guide | Google, Microsoft | Both — parallel Vale packages; project picks primary |
| Versioning trio | SemVer + Keep a Changelog + Conventional Commits | All three — orthogonal |
| Code of conduct | Contributor Covenant 2.1 | **Contributor Covenant 2.1** (40k+ projects, CC-BY-4.0) |
| Threat model | STRIDE, LINDDUN | **STRIDE** security default; **LINDDUN** when privacy/GDPR in scope |
| License headers | REUSE/SPDX | **REUSE 3.3** + SPDX expressions |
