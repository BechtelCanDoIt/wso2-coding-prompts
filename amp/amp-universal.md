# WSO2 Agent Manager — Universal Coding Standard

> **Applies to:** Every component in the repository — Go, TypeScript, and Python alike.
> Read this file first, then open the language-specific guide for your component.

---

## Quick Reference — Which File Do I Need?

| I am working on… | Language guide | This file |
|---|---|---|
| `agent-manager-service/` or `traces-observer-service/` | [`amp-go.md`](./amp-go.md) | ✅ Always |
| `console/` | [`amp-typescript.md`](./amp-typescript.md) | ✅ Always |
| `libs/amp-evaluation/` or `libs/amp-instrumentation/` | [`amp-python.md`](./amp-python.md) | ✅ Always |
| `helm/` | No language guide — follow Helm lint rules in CI | ✅ Always |
| `samples/` | Match the language of the sample | ✅ Always |

---

## Table of Contents

- [WSO2 Agent Manager — Universal Coding Standard](#wso2-agent-manager--universal-coding-standard)
  - [Quick Reference — Which File Do I Need?](#quick-reference--which-file-do-i-need)
  - [Table of Contents](#table-of-contents)
  - [1. Project Philosophy](#1-project-philosophy)
  - [2. Naming as Domain Language](#2-naming-as-domain-language)
  - [3. Feature Lifecycle](#3-feature-lifecycle)
  - [4. CI/CD — Every PR Must Pass](#4-cicd--every-pr-must-pass)
  - [5. Versioning \& Releases](#5-versioning--releases)
  - [6. How to Contribute a New Feature](#6-how-to-contribute-a-new-feature)

---

## 1. Project Philosophy

The WSO2 Agent Manager (`amp`) is a **production-grade, multi-component platform** for managing, observing, and evaluating AI agents. It is not a prototype.

Code written for this project will be read by engineers across many time zones, run in enterprise customer environments, and operated by teams who did not write it. Every line must reflect that responsibility.

**The bar is: would a senior WSO2 engineer be proud to ship this?**

---

## 2. Naming as Domain Language

The following terms are **proper nouns** in this codebase. Use them exactly — consistent capitalisation, consistent spelling — in all identifiers, comments, log messages, error strings, and documentation:

| Term | Meaning |
|---|---|
| `Agent` | An AI agent managed by the platform |
| `Project` | A grouping of agents within an organization |
| `Organization` / `Org` | The top-level tenant scope |
| `Gateway` | An LLM proxy gateway |
| `Monitor` | A scheduled evaluation job |
| `Evaluator` | A function or class that scores an agent trace |
| `Trace` | A full execution trace of an agent run |
| `AgentTrace` | A single agent's trace within a multi-agent trace |
| `LLMSpan` | A single LLM call within a trace |
| `EvalResult` | The scored output of an evaluator |

Abbreviations that are already established in the codebase (`org`, `proj`, `amp`) are acceptable. Inventing new abbreviations is not.

---

## 3. Feature Lifecycle

Large features follow a three-stage process:

1. **Idea** → GitHub Discussion (Ideas category)
2. **Design Proposal** → GitHub Discussion (Design Proposals category), using the proposal template. Tracked with labels: `Proposal/Draft` → `Proposal/Review` → `Proposal/Approved`
3. **Implementation** → GitHub Issues linked to the approved proposal, assigned to a milestone

Do not begin implementation before a design proposal is approved for non-trivial features.

---

## 4. CI/CD — Every PR Must Pass

All of the following checks must be green before a PR may be merged:

| Component | Checks |
|---|---|
| Go services | `golangci-lint`, `go test` (with PostgreSQL), Docker build |
| Helm charts | `helm lint`, `helm template`, `kubeconform` |
| Python packages | `pytest`, coverage, `pip build` |
| Console | TypeScript compile, `vitest`, ESLint |

**Do not disable checks.** If a check is flaky, fix the flakiness — do not silence it.

---

## 5. Versioning & Releases

- Releases use **semantic versioning**: `X.Y.Z`
- Platform release tags: `amp/vX.Y.Z` with a floating major tag `amp/vX`
- Python SDK packages (`amp-evaluation`, `amp-instrumentation`) are versioned independently and published to PyPI

**Do not bump versions manually.** All versioning is handled by the release workflows via `workflow_dispatch`. The release branch pattern is `amp-{version}` (e.g., `amp-0.9.0`).

---

## 6. How to Contribute a New Feature

1. **Check for an existing issue or discussion.** Don't duplicate work.
2. **Open a Discussion in the Ideas category** if the feature is non-trivial.
3. **Write a Design Proposal** for anything that touches multiple components or changes public APIs.
4. **Wait for `Proposal/Approved` label** before writing code.
5. **Open a draft PR early** — this makes review easier and catches design issues before significant code is written.
6. **Ensure all CI checks pass** before marking the PR ready for review.
7. **Update documentation** in `docs/` if you are changing user-visible behaviour.

---

*This is the root document of the WSO2 Agent Manager AI coding standards suite.*
*Language-specific guides: [`amp-go.md`](./amp-go.md) · [`amp-typescript.md`](./amp-typescript.md) · [`amp-python.md`](./amp-python.md)*
