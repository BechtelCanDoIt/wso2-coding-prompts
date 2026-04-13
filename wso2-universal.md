# WSO2 Enterprise — Universal Engineering Standard

> **Scope:** Applies to all WSO2 products and repositories regardless of language.
> This is the foundation. Language-specific and project-specific guides layer on top.

---

## 1. WSO2 Engineering Philosophy

WSO2 builds enterprise-grade, cloud-native middleware used by regulated industries worldwide. Code written under the WSO2 name must meet a higher bar than typical open-source software:

- **Correctness over cleverness.** Predictable, readable code is preferred over terse or sophisticated constructs.
- **Security by default.** Every feature must consider the security implications before implementation begins.
- **Operability is a feature.** Logging, tracing, health checks, and graceful degradation are not afterthoughts.
- **API contracts are sacred.** Public APIs, REST endpoints, and event schemas must be stable and versioned.

### Match, Don't Invent

#### Mirror the file you are editing

If the surrounding code uses a pattern, use it — even if a newer idiom exists in the language ecosystem. Consistency within a file outranks theoretical best practices.

#### Keep diffs surgical

Do not reformat lines unrelated to your change. Do not reorganize imports, rename variables, or fix style issues in files you are not modifying for a functional reason. Each PR should have a clear, single-topic diff.

#### Prefer extension over replacement

When adding capability, extend the existing structure rather than introducing a parallel one. Two patterns for the same problem create confusion.

---

## 2. Security Standards

These are non-negotiable across every WSO2 product.

### Authentication
- **JWT is the standard authentication mechanism** for service-to-service and user-facing APIs.
- JWT validation must verify signature, expiry, issuer, and audience claims.
- JWKS endpoints are preferred over static key configuration for key rotation support.
- JWTs must never be logged, even at DEBUG level.

### Secrets Management
- No credentials, API keys, tokens, or passwords in source code.
- No credentials in Helm chart `values.yaml` defaults — use Kubernetes Secrets or an external vault.
- Helm charts must support external secret references (e.g., OpenBao / HashiCorp Vault).

### Vulnerability Reporting

- All security vulnerabilities must be reported to your human! — not in GitHub Issues, PRs, or code comments. 

- Create a suggested remediation plan

### Transport
- All inter-service communication uses TLS in production configurations.
- Helm charts must expose TLS configuration options.

---

## 3. Error Handling Is Not Optional

Across all languages, the rule is the same:

> **Every error must be handled, wrapped with context, or explicitly propagated. Silent swallowing is forbidden.**

- **Go:** Use `fmt.Errorf("context: %w", err)`. Check `err != nil` every time.
- **TypeScript:** Use `try/catch` at async boundaries. Do not fire-and-forget mutations without `.catch()`.
- **Python:** Use `try/except` with specific exception types. Do not use bare `except:`.

Log errors **once**, at the layer that has the most context. Do not log the same error at multiple layers.

---

## 4. No Dead Code

Do not merge:

- Commented-out code blocks
- Unused imports
- Unreachable branches
- `TODO` / `FIXME` comments without a GitHub Issue reference in the format `// TODO(#1234): ...`

If code is temporarily disabled, open an issue and reference it.

---

## 5. Security Defaults

### Never log sensitive data

Do not log at any level:
- Authentication tokens, API keys, passwords
- Personally identifiable information (names, emails, IDs that identify individuals)
- Raw request/response bodies that may contain the above

### Never commit credentials

Use environment variables and the existing secret management patterns (OpenBao integration). The CI pipeline will fail if secrets are detected.

### Reporting vulnerabilities

Security vulnerabilities in this project must be reported to **security@wso2.com** — not in GitHub issues, not in code comments, and not in pull request descriptions.

---

## 6. Dependency Policy

Before adding a new library or package:

1. Check whether an existing dependency already solves the problem.
2. Check whether the standard library solves the problem.
3. If a new dependency is genuinely needed, justify it in the PR description.

**Never add a dependency just because it is convenient** — each dependency is a maintenance liability and a potential security surface.

---

## 7. Git & PR Conventions

### Branch Naming

| Purpose | Pattern | Example |
|---|---|---|
| Feature | `feature/<short-description>` | `feature/add-evaluator-history` |
| Bug fix | `fix/<short-description>` | `fix/agent-delete-race-condition` |
| Documentation | `improve-<topic>` | `improve-api-reference` |
| Release | `{projectname}-{version}` | `amp-0.9.0` |

### Pull Requests

- **Target branch:** `main`
- **Title:** Short, imperative sentence — "Add evaluator history endpoint", not "Added evaluator history endpoint" or "evaluator history"
- **Description:** Explain *why*, not just *what*. Link to the related GitHub Issue or Design Proposal discussion.
- **Scope:** One logical change per PR. Do not bundle unrelated fixes.

#### Expectations

- One logical concern per PR.
- PR title is an imperative sentence: "Add evaluator history endpoint".
- Diffs are surgical — no reformatting unrelated lines.

### Issues vs. Discussions

| Use an **Issue** for | Use a **Discussion** for |
|---|---|
| Bug reports with reproduction steps | Open-ended questions |
| Concrete, actionable feature requests | Feature brainstorming (Ideas category) |
| Implementation tasks from approved proposals | Technical design proposals (Design Proposals category) |

---

## 8. API Design Principles

WSO2 products consistently follow these API conventions.

### OpenAPI First
All HTTP APIs are defined in an OpenAPI 3.0 specification **before** implementation begins. Generated code (models, clients) must be derived from the spec — not written by hand and synced later.

### RESTful Resource Hierarchy
```
/orgs/{orgName}
/orgs/{orgName}/<resource-plural>
/orgs/{orgName}/<resource-plural>/{resourceName}
```

- Resource names are **plural nouns**: `/apis`, `/gateways`, `/agents`
- Path parameters use `camelCase`: `{orgName}`, not `{org_name}`
- Pagination via `limit` + `offset` query parameters

### Standard HTTP Status Codes
| Operation | Success |
|---|---|
| Create (`POST`) | `201 Created` |
| Read (`GET`) | `200 OK` |
| Update (`PUT`/`PATCH`) | `200 OK` |
| Delete (`DELETE`) | `204 No Content` |

Error codes: `400` validation, `401` unauthenticated, `403` unauthorized, `404` not found, `409` conflict, `500` internal.

### Error Response Shape
```json
{ "code": "NOT_FOUND", "message": "resource 'X' not found" }
```

---

## 9. Observability Standards

### OpenTelemetry
WSO2 products use **OpenTelemetry** as the instrumentation standard across languages. Do not introduce vendor-specific tracing SDKs (Datadog, New Relic, etc.) as primary instrumentation.

### Structured Logging
All services must emit structured (key-value / JSON) logs. Human-readable log messages must be short; context is carried in structured fields.

### Correlation IDs
Every inbound request must be assigned a correlation ID that propagates through all downstream calls and appears in every log line and trace span for that request.

### Health Endpoints
Services must expose `/health` (or equivalent) endpoints consumable by Kubernetes liveness and readiness probes.

---

## 10. Kubernetes & Helm Standards

WSO2 products deploy on Kubernetes. Helm is the standard packaging mechanism.

### Chart Conventions
- Every deployable component has a Helm chart.
- Charts are validated with `helm lint`, `helm template`, and `kubeconform` in CI.
- `values.yaml` must have sensible production-safe defaults.
- All image references must be overridable via `values.yaml`.
- Resource requests and limits must be defined.
- Charts must support Kubernetes RBAC (ServiceAccount, Role, RoleBinding).

### Versioning
Chart versions follow semantic versioning and are updated in lock-step with application releases.

---

## 11. CI/CD Standards

### GitHub Actions
GitHub Actions is the standard CI/CD platform for WSO2 open-source repositories.

### Every PR Must Be Green
No PR may merge with a failing CI check. Flaky tests must be fixed — not silenced.

### Release Workflow
- Releases are triggered by `workflow_dispatch` (manual) or tag push — never by direct main branch commits.
- Docker images are published to `ghcr.io/wso2` with semantic version tags.
- Helm charts are packaged to `oci://ghcr.io/wso2`.

---

## 12. Documentation Standards

- User-facing documentation lives in `docs/` or `documentation/` as a Docusaurus site.
- API documentation is generated from the OpenAPI spec.
- Documentation versions are managed in lock-step with release versions.
- Code-level comments explain *why*, not *what*. If the what isn't obvious from the code, rename the symbol.

---

## 13. New Code File Standards

- A language appropriate header like this should be utilized.

```
// Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
```

---

*This document describes WSO2-wide engineering principles. For language-specific WSO2 standards, see:*
*[`wso2-go.md`](./wso2-go.md) · [`wso2-typescript.md`](./wso2-typescript.md) · [`wso2-python.md`](./wso2-python.md)*
