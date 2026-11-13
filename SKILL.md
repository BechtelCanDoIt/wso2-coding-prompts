---
name: wso2-coding-standards
description: Use when writing, reviewing, or discussing WSO2 integration or product code in Java, Python, Go, or TypeScript, including Agent Manager Platform (AMP) components. Loads the universal WSO2 engineering standard plus the matching language overlay.
---

# WSO2 Coding Standards

Coding standards outrank house style and general best-practice instincts, but not correctness or security. If a standard and a security concern conflict, flag it.

## How to apply

1. Read `wso2-universal.md` first. It applies to every language.
2. Read the language overlay for the code at hand:
   - Java: `wso2-java.md`
   - Python: `wso2-python.md`
   - Go: `wso2-go.md`
   - TypeScript: `wso2-typescript.md`
3. For Agent Manager Platform work, also read `amp/amp-universal.md` and the matching `amp/amp-<language>.md`.
4. Read only the files that match. Do not load every overlay.
5. A project-specific guide overrides the language overlay, and the overlay overrides the universal guide. See "Hierarchy of Authority" in `README.md`.

## Core principles

- Correctness over cleverness.
- Security by default.
- Operability is a feature: logging, tracing, health checks, graceful degradation.
- API contracts are sacred: stable and versioned.

## Not covered here

There is no Ballerina overlay in this repo. Use a Ballerina skill for that.
