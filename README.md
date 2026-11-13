# WSO2 Coding Prompts

A comprehensive collection of WSO2 engineering standards, coding guidelines, and best practices across multiple programming languages and product lines.

## Overview
This project was created by Claude Opus by reviewing project code in WSO2 Agent Manager project for Go and WSO2 APIM for Java standards.

This repository sits on top of this project: https://github.com/BechtelCanDoIt/wso2-engineering-governance 

This repository contains standardized coding prompts and engineering guidelines for WSO2 development. These guides establish a unified approach to code quality, security, and architecture across all WSO2 products and repositories.

### Key Principles

WSO2 builds **enterprise-grade, cloud-native middleware** used by regulated industries worldwide. All code written under the WSO2 name must adhere to these core principles:

- **Correctness over cleverness** — Predictable, readable code is preferred over terse or sophisticated constructs
- **Security by default** — Every feature must consider security implications before implementation
- **Operability is a feature** — Logging, tracing, health checks, and graceful degradation are essential
- **API contracts are sacred** — Public APIs, REST endpoints, and event schemas must be stable and versioned

---

## Directory Structure

```
wso2codingprompts/
├── README.md                      # This file
├── wso2-universal.md              # Universal engineering standards (applies to all languages)
├── wso2-java.md                   # Java-specific coding standards
├── wso2-python.md                 # Python-specific coding standards
├── wso2-go.md                     # Go-specific coding standards
├── wso2-typescript.md             # TypeScript-specific coding standards
└── amp/                           # Agent Manager Platform standards
    ├── amp-universal.md           # Universal standards for AMP (applies to all AMP components)
    ├── amp-go.md                  # Go-specific standards for AMP
    ├── amp-python.md              # Python-specific standards for AMP
    └── amp-typescript.md          # TypeScript-specific standards for AMP
```

---

## Files and Their Purpose

### WSO2 Enterprise Standards

#### `wso2-universal.md`
Foundation document that applies to **all WSO2 products and repositories** regardless of programming language.

**Key Topics:**
- WSO2 engineering philosophy
- Security standards (authentication, secrets management, vulnerability reporting)
- API design and versioning
- Testing and quality assurance
- Code review practices
- Logging and observability
- Production readiness checklist

**Use this:** Before reading any language-specific guide

---

#### `wso2-java.md`
Standardized guidelines for **Java services and Carbon components** across all WSO2 repositories.

**Key Topics:**
- Maven multi-module project structure
- OSGi bundle conventions
- Logging framework standards (SLF4J/Log4j)
- Exception handling patterns
- Dependency injection and component architecture
- Testing with JUnit and TestNG
- Performance considerations
- Thread safety and concurrency patterns

**Applies to:** `product-apim`, `carbon-apimgt`, `msf4j`, and all WSO2 Java services

---

#### `wso2-python.md`
Standardized guidelines for **Python components** across WSO2 products.

**Key Topics:**
- Project structure and packaging
- Virtual environment setup
- Code style and linting (PEP 8, Black, isort)
- Type hints and mypy configuration
- Testing frameworks (pytest, unittest)
- Dependency management
- Logging standards
- Documentation conventions

**Applies to:** Python libraries, services, and tools in WSO2 products

---

#### `wso2-go.md`
Standardized guidelines for **Go services and components** in WSO2 products.

**Key Topics:**
- Project layout and package organization
- Error handling patterns
- Testing and benchmarking
- Dependency management (Go modules)
- Logging and structured logging
- HTTP API design
- Concurrency patterns
- Build and deployment conventions

**Applies to:** Go microservices and command-line tools

---

#### `wso2-typescript.md`
Standardized guidelines for **TypeScript/JavaScript components** in WSO2 products.

**Key Topics:**
- TypeScript configuration
- Module system and imports
- Async/await and Promise handling
- Testing frameworks (Jest, Mocha)
- Linting and formatting (ESLint, Prettier)
- Type definitions and interfaces
- Error handling
- Node.js compatibility and versioning

**Applies to:** Web consoles, APIs, and Node.js services

---

### WSO2 Agent Manager (AMP) Standards

The `amp/` directory contains specialized standards for the **WSO2 Agent Manager platform** — a production-grade, multi-component system for managing, observing, and evaluating AI agents.

#### `amp/amp-universal.md`
Foundation document for **all Agent Manager components** (Go, TypeScript, Python).

**Key Topics:**
- Project philosophy and production-readiness standards
- Naming conventions and domain language
- Feature lifecycle and approval process
- CI/CD requirements
- Versioning and release procedures
- Contribution workflow for new features

**Use this:** Before working on any AMP component

**Quick Reference:**
- Working on `agent-manager-service/` or `traces-observer-service/` → Use `amp-go.md`
- Working on `console/` → Use `amp-typescript.md`
- Working on `libs/amp-evaluation/` or `libs/amp-instrumentation/` → Use `amp-python.md`
- Working on Helm charts → Follow Helm lint rules

---

#### `amp/amp-go.md`
Go-specific standards for **Agent Manager Go services** (`agent-manager-service`, `traces-observer-service`).

**Key Topics:**
- Service architecture and design patterns
- API contract definitions
- Database and persistence layer standards
- Event-driven architecture
- Observability (metrics, tracing, logging)
- Testing strategies
- Deployment and operations

---

#### `amp/amp-python.md`
Python-specific standards for **Agent Manager Python libraries** (`amp-evaluation`, `amp-instrumentation`).

**Key Topics:**
- Library design and API stability
- Instrumentation patterns
- Evaluation frameworks
- Dependency management
- Testing and validation
- Documentation requirements
- Release and packaging

---

#### `amp/amp-typescript.md`
TypeScript-specific standards for **Agent Manager console and UI components**.

**Key Topics:**
- React component architecture
- State management patterns
- Testing for UI components
- Accessibility standards
- Performance optimization
- Build and deployment

---

## How to Use These Guides

### Getting Started

1. **New to WSO2?** Start with `wso2-universal.md` to understand the core engineering philosophy and non-negotiable standards.

2. **Working on a specific language?** Read the universal guide first, then the language-specific guide that matches your work.

3. **Working on Agent Manager?** Start with `amp/amp-universal.md`, then read the component-specific guide for your language.

4. **Existing project?** Check if there's a project-specific guide that layers on top of these standards.

### Hierarchy of Authority

Standards are layered — more specific guides override general ones:

```
Project-Specific Guide (highest priority)
         ↓
Language-Specific Guide (Java, Go, Python, TypeScript)
         ↓
Product/Platform Guide (WSO2 Enterprise or Agent Manager)
         ↓
https://github.com/BechtelCanDoIt/wso2-engineering-governance
         ↓
Universal Engineering Standards (foundation)
```

For example:
- A Java project-specific guide overrides `wso2-java.md`
- `wso2-java.md` overrides `wso2-universal.md` when there's a conflict
- Always prefer consistency with your surrounding code

---

## Use as a Claude Code Skill

This repo is also a Claude Code skill. `SKILL.md` at the repo root tells Claude to read `wso2-universal.md` first, then the one language overlay that matches the code (and the `amp/` files for Agent Manager work).

Install it by cloning into your skills folder:

```bash
git clone https://github.com/BechtelCanDoIt/wso2-coding-prompts ~/.claude/skills/wso2-coding-standards
```

Skills load when Claude judges a request matches their description, which everyday coding requests often do not. To make it harder to miss, add the optional session-start hook. It prints a one-line reminder, only inside a code project (a git repo, or a folder with `pom.xml`, `go.mod`, `pyproject.toml`, `package.json` or `requirements.txt`). It needs `jq`.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/skills/wso2-coding-standards/hooks/coding-standards-nudge.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Put that under `hooks` in `~/.claude/settings.json`. The reminder is a nudge, so Claude still decides whether to load the skill.

---

## Key Standards Across All Guides

### Security

- JWT is the standard authentication mechanism
- JWKS endpoints preferred over static key configuration
- No credentials, API keys, or tokens in source code
- No credentials in configuration defaults — use external vaults
- All security vulnerabilities reported privately, never in public issues

### Code Quality

- Prefer clarity and maintainability
- Keep diffs surgical and focused
- Mirror surrounding code patterns for consistency
- Extend existing structures rather than inventing parallel ones
- Each PR should have a clear, single-topic diff

### Operability

- Structured logging with appropriate log levels
- Distributed tracing support
- Health check endpoints
- Graceful degradation and error handling
- Clear error messages and observability hooks

### Testing

- Unit tests required for all functionality
- Integration tests for external dependencies
- Coverage targets vary by project but aim for >80%
- Test execution must be deterministic and repeatable

### API Design

- REST endpoints follow consistent patterns
- API versions are immutable and stable
- Breaking changes require major version bumps
- Event schemas must be versioned
- Backward compatibility is a first-class concern

---

## Contributing

When contributing code:

1. Read the **universal** guide for your product/platform
2. Read the **language-specific** guide
3. Check for **project-specific** guides in the repository
4. Match the patterns you see in the existing codebase
5. Ensure all PRs pass CI/CD requirements outlined in the relevant guide

---

## Related Resources

- **WSO2 Main Repository:** https://github.com/wso2
- **Agent Manager Repository:** Check the `CONTRIBUTING.md` in your fork
- **Security:** Report vulnerabilities privately to your engineering lead

---

## Quick Checklist Before Committing

- [ ] Read and understand the relevant universal guide
- [ ] Read and understand the relevant language-specific guide
- [ ] Code matches surrounding patterns and style
- [ ] All tests pass locally
- [ ] Security checklist complete (no secrets, JWT handling, etc.)
- [ ] API contracts are backward compatible (if applicable)
- [ ] Logging and observability are adequate for operations teams
- [ ] Diff is focused and single-topic

---

## Version History

- **v1.0** — Initial standardization across WSO2 products
- **v1.1** — Agent Manager (AMP) standards added

---

## Questions?

Refer to the relevant guide for your work, or consult with your engineering lead or project maintainer.
