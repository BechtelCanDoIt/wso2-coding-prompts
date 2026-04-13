# WSO2 Enterprise — Go Coding Standard

> **Scope:** All WSO2 Go services and libraries across all repositories.
> Project-specific guides layer on top and win on conflict.

---

## 1. Project Layout

WSO2 Go services follow a variation of the standard Go project layout. The `internal/` package convention is used to enforce encapsulation — packages under `internal/` cannot be imported by external modules.

```
service/
├── cmd/             # Main packages — binary entry points
├── internal/        # Private implementation packages
│   ├── api/         # HTTP routing and handler wiring
│   ├── config/      # Configuration structs and loaders
│   ├── models/      # Domain data structures
│   └── ...          # Domain-specific sub-packages
├── pkg/             # Public library packages importable by other modules
└── docs/            # OpenAPI specs and generated documentation
```

Adapt this to the specific service, but always use `internal/` for packages that are not intended as a public API.

---

## 2. Naming Conventions

| Construct | Convention | Example |
|---|---|---|
| Package | Short, lowercase, no underscores | `config`, `models`, `middleware` |
| Interface | Noun or noun + role suffix | `Repository`, `AgentService` |
| Concrete struct | Unexported, no suffix | `agentService`, `configLoader` |
| Constructor | `New` prefix | `NewAgentService(...)` |
| Exported constant | `CamelCase` | `DefaultPageSize` |
| Unexported constant | `camelCase` | `defaultRetryCount` |
| Test function | `Test` + subject | `TestCreateAgent` |

---

## 3. Interfaces

- Define interfaces in the package that **consumes** them.
- Keep interfaces small — prefer many focused interfaces over one large one.
- Name interfaces after the behaviour they describe, not the implementation.

```go
// Good — small, focused
type TokenValidator interface {
    Validate(ctx context.Context, token string) (*Claims, error)
}

// Bad — too large, multiple responsibilities
type AuthManager interface {
    ValidateToken(token string) (*Claims, error)
    RefreshToken(token string) (string, error)
    RevokeToken(token string) error
    ListActiveSessions(userID string) ([]Session, error)
}
```

---

## 4. Error Handling

- Return `error` from every function that can fail. Do not panic on recoverable errors.
- Wrap errors with context using `fmt.Errorf("context: %w", err)` at every layer crossing.
- Define sentinel errors for conditions callers need to distinguish:

```go
var (
    ErrNotFound  = errors.New("resource not found")
    ErrConflict  = errors.New("resource already exists")
    ErrForbidden = errors.New("operation not permitted")
)
```

- Never silently swallow an error. Every `err != nil` must be handled, wrapped, or returned.

---

## 5. Context Propagation

- `context.Context` is always the **first parameter** of functions that perform I/O.
- Never store a context in a struct field.
- Use `context.WithTimeout` or `context.WithDeadline` at I/O boundaries (DB calls, external HTTP).

---

## 6. Logging

WSO2 Go services use structured logging. The exact library varies by project (see project-specific guide), but all must:

- Emit structured key-value log entries (not interpolated strings).
- Use consistent field names: `"error"`, `"org"`, `"component"`.
- Log at the appropriate level — do not use DEBUG in production hot paths.
- Never log tokens, passwords, secrets, or PII.

```go
// Good — structured, consistent field names
logger.Info("processing request", "org", orgName, "request_id", requestID)
logger.Error("failed to fetch resource", "error", err, "resource", resourceName)

// Bad — interpolated, unstructured
log.Printf("processing request for org %s", orgName)
```

---

## 7. HTTP Services

### Middleware
Cross-cutting concerns (auth, logging, recovery, CORS, correlation ID) belong in middleware — not in handlers.

Standard middleware applied to all WSO2 Go HTTP services:
- **Panic recovery** — prevent a single handler panic from crashing the service.
- **Correlation ID** — assign and propagate a request-scoped ID.
- **Request logging** — log method, path, status, and duration for every request.
- **CORS** — configure appropriately; do not use wildcard origins in production.
- **JWT validation** — on all authenticated routes.

### Handlers
Handlers have one job: parse input → validate → delegate to business logic → write response. No business logic in handlers.

---

## 8. Testing

### Frameworks
- Standard `testing` package + `github.com/stretchr/testify/assert` and `require`.
- `require.*` for fatal assertions; `assert.*` for non-fatal.

### Naming and Structure
- Test files: `*_test.go`
- Test functions: `TestXxx` matching the function under test
- Table-driven tests with `t.Run` for multiple cases

### Mocking
Prefer hand-crafted mock structs with function fields over code-generated mocks for simplicity and readability. Use generated mocks only when the interface is large and manually maintained mocks become a burden.

---

## 9. Code Quality

- `gofmt` is non-negotiable — all Go code must be formatted.
- `golangci-lint` runs in CI; fix lint errors, do not suppress them.
- No `init()` functions for business logic or dependency setup.
- No package-level mutable global state.

---

*WSO2 Go base standard. See project-specific guide for overrides and additions.*
