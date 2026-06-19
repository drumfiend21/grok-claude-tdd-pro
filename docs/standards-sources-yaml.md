# Standards sources — YAML corpus

Stable in-repo mirror of the 75-source YAML standards bundle assembled in the 2026-06-19 GCTP research session. Cited by `docs/adr/0066-yaml-json-md-corpora-and-prose-as-code-enforcement.md` and by upstream `proposals/PROPOSAL-003-ctp-session-brief.md`.

**License posture summary:**
- **Mirror permitted** (raw MD pin-by-commit; or static HTML cache): Apache 2.0, MIT, CC-BY-4.0, CC-BY-SA-4.0, MPL 2.0, IETF RFC public.
- **Config / grammar mirror only with prominent attribution**: GPLv3 (yamllint, ansible-lint). Detector code MUST be independently authored.
- **Cite-link only — no body mirror**: CIS K8s Benchmark, AWS docs, Microsoft Learn, Snyk, Atlassian Bitbucket, blog posts.

## Master table (75 sources)

| # | Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|---|
| 1 | YAML 1.2.2 spec | YAML Language Dev Team | https://yaml.org/spec/1.2.2/ | HTML (stable) | Permissive — citable with attribution |
| 2 | YAML spec (raw MD) | yaml/yaml-spec | https://raw.githubusercontent.com/yaml/yaml-spec/main/spec/1.2.2/spec.md | RAW MD, pin by commit | MIT-style |
| 3 | yamllint default config | adrienverge/yamllint | https://raw.githubusercontent.com/adrienverge/yamllint/master/yamllint/conf/default.yaml | RAW YAML | GPLv3 (config-only mirror) |
| 4 | yamllint rules reference | yamllint | https://yamllint.readthedocs.io/en/stable/rules.html | HTML (Sphinx) | GPLv3 docs |
| 5 | K8s Pod Security Standards | kubernetes.io | https://kubernetes.io/docs/concepts/security/pod-security-standards/ | HTML (Hugo); src github.com/kubernetes/website | CC-BY 4.0 |
| 6 | K8s Configuration Best Practices | kubernetes.io | https://kubernetes.io/docs/concepts/configuration/overview/ | HTML | CC-BY 4.0 |
| 7 | K8s Security Context | kubernetes.io | https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ | HTML | CC-BY 4.0 |
| 8 | K8s RBAC | kubernetes.io | https://kubernetes.io/docs/reference/access-authn-authz/rbac/ | HTML | CC-BY 4.0 |
| 9 | K8s Secrets | kubernetes.io | https://kubernetes.io/docs/concepts/configuration/secret/ | HTML | CC-BY 4.0 |
| 10 | CIS Kubernetes Benchmark | CIS | https://www.cisecurity.org/benchmark/kubernetes | PDF gated | CIS EULA — cite-link only |
| 11 | kube-linter checks | stackrox/kube-linter | https://raw.githubusercontent.com/stackrox/kube-linter/main/docs/generated/checks.md | RAW MD, pin by commit | Apache 2.0 |
| 12 | kube-linter templates | stackrox/kube-linter | https://raw.githubusercontent.com/stackrox/kube-linter/main/docs/generated/templates.md | RAW MD | Apache 2.0 |
| 13 | Polaris checks | FairwindsOps/polaris | https://github.com/FairwindsOps/polaris/tree/master/checks | RAW JSON-schema, pin by commit | Apache 2.0 |
| 14 | Polaris docs | polaris.docs.fairwinds.com | https://polaris.docs.fairwinds.com/checks/ | HTML (Docusaurus) | Apache 2.0 |
| 15 | kubeconform | yannh/kubeconform | https://github.com/yannh/kubeconform | RAW (README + schemas) | Apache 2.0 |
| 16 | Kubernetes JSON Schemas | yannh/kubernetes-json-schema | https://github.com/yannh/kubernetes-json-schema | RAW JSON schemas | Apache 2.0 |
| 17 | Kubescape regolibrary controls | kubescape/regolibrary | https://raw.githubusercontent.com/kubescape/regolibrary/master/controls/ | RAW JSON+Rego | Apache 2.0 |
| 18 | Kubescape frameworks (NSA/CIS/MITRE/SSDF) | kubescape/regolibrary | https://github.com/kubescape/regolibrary/tree/master/frameworks | RAW JSON | Apache 2.0 |
| 19 | Helm chart best practices | helm.sh | https://helm.sh/docs/chart_best_practices/ | HTML (Hugo); src github.com/helm/helm-www | Apache 2.0 |
| 20 | Helm values best practices | helm.sh | https://helm.sh/docs/chart_best_practices/values/ | HTML | Apache 2.0 |
| 21 | Helm values.schema.json guide | helm.sh | https://helm.sh/docs/topics/charts/#schema-files | HTML | Apache 2.0 |
| 22 | Docker Compose spec | compose-spec/compose-spec | https://raw.githubusercontent.com/compose-spec/compose-spec/main/spec.md | RAW MD | Apache 2.0 |
| 23 | Compose file reference | docs.docker.com | https://docs.docker.com/reference/compose-file/ | HTML | Apache 2.0 docs |
| 24 | GitHub Actions workflow syntax | docs.github.com | https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions | HTML; src github.com/github/docs | CC-BY 4.0 |
| 25 | GHA security hardening | docs.github.com | https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions | HTML | CC-BY 4.0 |
| 26 | GHA secure-use reference | docs.github.com | https://docs.github.com/en/actions/reference/security/secure-use | HTML | CC-BY 4.0 |
| 27 | GHA OIDC w/ AWS | docs.github.com | https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services | HTML | CC-BY 4.0 |
| 28 | GHA concurrency | docs.github.com | https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency | HTML | CC-BY 4.0 |
| 29 | GitLab CI YAML reference | docs.gitlab.com | https://docs.gitlab.com/ci/yaml/ | HTML | CC-BY-SA 4.0 |
| 30 | GitLab CI job rules | docs.gitlab.com | https://docs.gitlab.com/ci/jobs/job_rules/ | HTML | CC-BY-SA 4.0 |
| 31 | Azure Pipelines YAML schema | learn.microsoft.com | https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/ | HTML | MS proprietary — cite-link |
| 32 | Azure Pipelines templates-for-security | learn.microsoft.com | https://learn.microsoft.com/en-us/azure/devops/pipelines/security/templates | HTML | MS proprietary |
| 33 | CircleCI config reference | circleci.com | https://circleci.com/docs/configuration-reference/ | HTML; src github.com/circleci/circleci-docs | docs Apache 2.0 |
| 34 | Bitbucket Pipelines config ref | atlassian.com | https://support.atlassian.com/bitbucket-cloud/docs/bitbucket-pipelines-configuration-reference/ | HTML | Atlassian — cite-link |
| 35 | Jenkins Pipeline-as-YAML | jenkins.io | https://plugins.jenkins.io/pipeline-as-yaml/ | HTML | MIT (plugin) |
| 36 | ansible-lint rules | docs.ansible.com | https://docs.ansible.com/projects/lint/rules/ | HTML (Sphinx) | GPLv3 + CC-BY |
| 37 | ansible-lint repo rules | ansible/ansible-lint | https://github.com/ansible/ansible-lint/tree/main/src/ansiblelint/rules | RAW Python+MD | GPLv3 |
| 38 | Ansible best practices | docs.ansible.com | https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html | HTML | GPLv3 + CC-BY |
| 39 | CloudFormation best practices | docs.aws.amazon.com | https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html | HTML | AWS proprietary — cite-link |
| 40 | CFN template anatomy | docs.aws.amazon.com | https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-anatomy.html | HTML | AWS proprietary |
| 41 | OpenAPI 3.1 spec | OAI/OpenAPI-Specification | https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.1.0.md | RAW MD | Apache 2.0 |
| 42 | OpenAPI 3.0.4 spec | OAI | https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.0.4.md | RAW MD | Apache 2.0 |
| 43 | Argo CD sync waves | argo-cd.readthedocs.io | https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ | HTML (Sphinx); src github.com/argoproj/argo-cd/tree/master/docs/user-guide | Apache 2.0 |
| 44 | Argo CD sync options | argo-cd.readthedocs.io | https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/ | HTML | Apache 2.0 |
| 45 | Flux Kustomize API v1 | fluxcd.io | https://fluxcd.io/flux/components/kustomize/api/v1/ | HTML (Hugo); src github.com/fluxcd/website | Apache 2.0 |
| 46 | Flux Kustomization spec | fluxcd.io | https://fluxcd.io/flux/components/kustomize/kustomizations/ | HTML | Apache 2.0 |
| 47 | Kustomize patches docs | kubernetes.io | https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/ | HTML | CC-BY 4.0 |
| 48 | Sealed Secrets | bitnami-labs/sealed-secrets | https://raw.githubusercontent.com/bitnami-labs/sealed-secrets/main/README.md | RAW MD | Apache 2.0 |
| 49 | SOPS | getsops/sops | https://raw.githubusercontent.com/getsops/sops/main/README.rst | RAW rST | MPL 2.0 |
| 50 | Prometheus config | prometheus.io | https://prometheus.io/docs/prometheus/latest/configuration/configuration/ | HTML (Hugo); src github.com/prometheus/docs | Apache 2.0 + docs CC-BY-4.0 |
| 51 | Prometheus alerting rules | prometheus.io | https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/ | HTML | Apache 2.0 |
| 52 | Prometheus recording rules | prometheus.io | https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/ | HTML | Apache 2.0 |
| 53 | OTel Collector configuration | open-telemetry/opentelemetry.io | https://raw.githubusercontent.com/open-telemetry/opentelemetry.io/main/content/en/docs/collector/configuration.md | RAW MD | CC-BY 4.0 |
| 54 | Istio VirtualService | istio.io | https://istio.io/latest/docs/reference/config/networking/virtual-service/ | HTML (Hugo); src github.com/istio/istio.io | Apache 2.0 |
| 55 | Istio DestinationRule | istio.io | https://istio.io/latest/docs/reference/config/networking/destination-rule/ | HTML | Apache 2.0 |
| 56 | Istio PeerAuthentication | istio.io | https://istio.io/latest/docs/reference/config/security/peer_authentication/ | HTML | Apache 2.0 |
| 57 | Envoy config reference | envoyproxy.io | https://www.envoyproxy.io/docs/envoy/latest/configuration/configuration | HTML (Sphinx) | Apache 2.0 |
| 58 | Kong declarative config | docs.konghq.com | https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/ | HTML | Apache 2.0 docs |
| 59 | OWASP CI/CD Top 10 | OWASP | https://github.com/OWASP/www-project-top-10-ci-cd-security-risks | RAW MD + HTML | CC-BY-SA 4.0 |
| 60 | OWASP CI/CD Cheat Sheet | OWASP/CheatSheetSeries | https://raw.githubusercontent.com/OWASP/CheatSheetSeries/master/cheatsheets/CI_CD_Security_Cheat_Sheet.md | RAW MD | CC-BY-SA 4.0 |
| 61 | OWASP API Security Top 10 (2023) | OWASP/API-Security | https://github.com/OWASP/API-Security | RAW MD | CC-BY-SA 4.0 |
| 62 | OpenSSF Scorecard checks | ossf/scorecard | https://raw.githubusercontent.com/ossf/scorecard/main/docs/checks.md | RAW MD | Apache 2.0 |
| 63 | SLSA v1.0 requirements | slsa.dev | https://slsa.dev/spec/v1.0/requirements | HTML (Hugo) | CC-BY 4.0 |
| 64 | SLSA security levels | slsa.dev | https://slsa.dev/spec/v1.0/levels | HTML | CC-BY 4.0 |
| 65 | NIST SP 800-218 SSDF v1.1 | NIST | https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-218.pdf | PDF | US Gov public domain |
| 66 | Checkov policy index — all | bridgecrewio/checkov | https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/all.md | RAW MD | Apache 2.0 |
| 67 | Checkov K8s policies | bridgecrewio/checkov | https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/kubernetes.md | RAW MD | Apache 2.0 |
| 68 | Checkov GitHub Actions policies | bridgecrewio/checkov | https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/github_actions.md | RAW MD | Apache 2.0 |
| 69 | Trivy checks bundle | aquasecurity/trivy-checks | https://github.com/aquasecurity/trivy-checks | RAW Rego + MD | Apache 2.0 |
| 70 | Trivy misconfig docs | trivy.dev | https://trivy.dev/latest/docs/scanner/misconfiguration/ | HTML (MkDocs) | Apache 2.0 |
| 71 | conftest | open-policy-agent/conftest | https://raw.githubusercontent.com/open-policy-agent/conftest/master/README.md | RAW MD | Apache 2.0 |
| 72 | Snyk K8s IaC rules | snyk.io | https://snyk.io/security-rules/kubernetes/deployment | HTML (Next.js partial-SPA) | Snyk copyright — cite-link |
| 73 | OpenGitOps principles | open-gitops/documents | https://raw.githubusercontent.com/open-gitops/documents/main/PRINCIPLES.md | RAW MD | Apache 2.0 |
| 74 | Google styleguide repo | google/styleguide | https://github.com/google/styleguide | RAW + GH Pages | Apache 2.0 |
| 75 | OpenShift security hardening | docs.openshift.com | https://docs.openshift.com/container-platform/latest/security/container_security/security-hardening.html | HTML | Red Hat docs CC-BY-SA |

## Highest-leverage seeds (start order for upstream CTP authoring)

1. **Checkov policy index `all.md`** (#66) — Apache 2.0, 1000+ rules across K8s/CFN/GHA/GitLab CI/Azure Pipelines/Argo/Ansible. Single biggest density per ingest hour.
2. **kube-linter `checks.md`** (#11) — Apache 2.0, canonical K8s catalog. ~50 built-in checks each with stable ID like `no-extensions-v1beta`, `privileged-container`, `required-label`.
3. **Trivy-checks Rego repo** (#69) — Apache 2.0, ~700 Rego checks across K8s/Docker/CFN/Terraform/GitHub Actions/Dockerfile. OCI-distributable.
4. **Kubescape regolibrary** (#17/#18) — Apache 2.0, ~80 controls pre-mapped to NSA-CISA / CIS / MITRE ATT&CK / NIST SSDF for automatic compliance attribution.
5. **yamllint `default.yaml`** (#3) — GPLv3 config-only mirror, YAML-syntax floor (anchors, key-duplicates, indentation, line-length).

## Excluded / superseded (do not seed from these)

- **Datree** — acquired by GitHub, project archived; superseded by Trivy / kube-linter / Polaris.
- **GKE / EKS / AKS "Pod hardening" guides** — restate Kubernetes Pod Security Standards (#5). Pick the upstream.
- **CIS GKE / EKS subprofiles** — extracts of #10. Pick the master.

## Secondary / citation-only references

- bram.us blog post on the Norway problem (https://www.bram.us/2022/01/11/yaml-the-norway-problem/) — copyrighted, link-only.
- InfoWorld "7 YAML gotchas" (https://www.infoworld.com/article/2336307/...) — copyrighted, link-only.
