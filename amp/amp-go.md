# WSO2 Agent Manager — Go Coding Standard

> **Applies to:** `agent-manager-service/` (`amp-api`) and `traces-observer-service/` (`amp-trace-observer`)
> **Stack:** Go, chi router, GORM, google/wire, log/slog, PostgreSQL

---

## Table of Contents

1. [Package Layout](#1-package-layout)
2. [Naming Conventions](#2-naming-conventions)
3. [Interfaces First](#3-interfaces-first)
4. [Error Handling](#4-error-handling)
5. [Context Propagation](#5-context-propagation)
6. [Structured Logging](#6-structured-logging)
7. [Dependency Injection (google/wire)](#7-dependency-injection-googlewire)
8. [HTTP Controllers](#8-http-controllers)
9. [HTTP Middleware](#9-http-middleware)
10. [Database Conventions (GORM)](#10-database-conventions-gorm)
11. [REST API Conventions](#11-rest-api-conventions)
12. [Testing](#12-testing)
13. [Hard Rules — Never Do This](#13-hard-rules--never-do-this)

---

## 1. Package Layout

Never create packages outside this hierarchy without a design discussion.

```
agent-manager-service/
├── api/            # HTTP routing only — mounts controllers, applies middleware chains
├── clients/        # External service clients (OpenChoreo, OpenBao, etc.)
├── config/         # App configuration structs and loaders
├── controllers/    # HTTP request handlers: parse → validate → delegate → respond
├── db_migrations/  # SQL migration files ONLY — no Go logic here
├── middleware/     # Cross-cutting HTTP concerns (auth, logging, recovery, CORS)
├── models/         # GORM DB structs + OpenAPI-generated request/response DTOs
├── repositories/   # Data access layer — ALL DB queries live here
├── services/       # Business logic — orchestrates repositories and clients
├── utils/          # Pure helper functions with no business logic
└── wiring/         # google/wire dependency injection providers
```

### Layer Responsibility Rules

| Layer | Allowed | Forbidden |
|---|---|---|
| `controllers/` | Parse request, validate input, call one service method, write response | Any DB access, any business logic |
| `services/` | Business logic, orchestrate repos and clients | Direct DB queries, writing HTTP responses |
| `repositories/` | GORM queries, transactions | Business logic, HTTP concerns |
| `utils/` | Pure functions, no I/O | Anything stateful |

---

## 2. Naming Conventions

| Construct | Convention | Example |
|---|---|---|
| Interface | Noun + role suffix | `AgentRepository`, `MonitorService` |
| Concrete struct (unexported) | Role descriptor, no suffix | `agentRepository`, `monitorService` |
| Constructor | `New` prefix | `NewAgentRepository(db *gorm.DB)` |
| HTTP handler method | Verb + resource noun | `CreateAgent`, `ListGateways`, `DeleteMonitor` |
| Exported constant | `CamelCase` | `DefaultPageLimit` |
| Package-level constant | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| Test function | `Test` + function name | `TestCreateAgent`, `TestListMonitors` |
| Test helper | `setup` / `teardown` prefix | `setupTestDB`, `teardownTestAgent` |

Domain concepts — `Agent`, `Project`, `Organization`, `Gateway`, `Monitor`, `Evaluator` — are **proper nouns**. Spell them consistently everywhere: variables, functions, URL path segments, log keys.

---

## 3. Interfaces First

Every layer boundary is an interface. Define the interface in the package that **consumes** it, not the package that implements it.

```go
// services/agent_service.go — interface consumed by controllers
type AgentService interface {
    Create(ctx context.Context, req models.CreateAgentRequest) (*models.Agent, error)
    Get(ctx context.Context, orgName, projName, agentName string) (*models.Agent, error)
    List(ctx context.Context, orgName, projName string, limit, offset int) ([]models.Agent, int, error)
    Update(ctx context.Context, req models.UpdateAgentRequest) (*models.Agent, error)
    Delete(ctx context.Context, orgName, projName, agentName string) error
}

// repositories/agent_repository.go — interface consumed by services
type AgentRepository interface {
    Create(ctx context.Context, agent *models.Agent) error
    Get(ctx context.Context, orgName, projName, agentName string) (*models.Agent, error)
    List(ctx context.Context, orgName, projName string, limit, offset int) ([]models.Agent, int, error)
    Update(ctx context.Context, agent *models.Agent) error
    Delete(ctx context.Context, orgName, projName, agentName string) error
    RunInTransaction(ctx context.Context, fn func(tx *gorm.DB) error) error
}
```

Interface names must reflect **behaviour**, not implementation: `AgentRepository` not `PostgresAgentRepository`.

---

## 4. Error Handling

### Wrap with context at every boundary

```go
// Good — each layer adds context
func (s *agentService) Get(ctx context.Context, orgName, projName, agentName string) (*models.Agent, error) {
    agent, err := s.repo.Get(ctx, orgName, projName, agentName)
    if err != nil {
        return nil, fmt.Errorf("agentService.Get: %w", err)
    }
    return agent, nil
}
```

### Typed errors for HTTP translation

Define sentinel errors in the repository layer; translate them to HTTP status codes in controllers:

```go
// repositories/errors.go
var (
    ErrNotFound = errors.New("resource not found")
    ErrConflict = errors.New("resource already exists")
)

// controllers/agent_controller.go
agent, err := c.agentService.Get(ctx, orgName, projName, agentName)
if err != nil {
    switch {
    case errors.Is(err, repositories.ErrNotFound):
        utils.WriteErrorResponse(w, http.StatusNotFound, "agent not found")
    case errors.Is(err, repositories.ErrConflict):
        utils.WriteErrorResponse(w, http.StatusConflict, "agent already exists")
    default:
        utils.WriteErrorResponse(w, http.StatusInternalServerError, "internal error")
    }
    return
}
```

### Rules

- Every `err != nil` must be **handled**, **wrapped**, or **returned**. Never ignore.
- Do not log the same error at multiple layers — log once, at the outermost layer that has full context.
- Use `utils.WriteErrorResponse` and `utils.WriteValidationErrorResponse` for all HTTP error responses. Never call `http.Error` or write raw JSON strings.

---

## 5. Context Propagation

- `context.Context` is **always the first argument** of any function that performs I/O.
- Never store a context in a struct field.
- Request-scoped values (logger, correlation ID) are extracted from context — never passed as separate parameters.

```go
// Good
func (r *agentRepository) Get(ctx context.Context, orgName, projName, agentName string) (*models.Agent, error) {
    log := slog.FromContext(ctx)
    log.Debug("fetching agent", "org", orgName, "project", projName, "agent", agentName)
    ...
}

// Bad — context not threaded through
func (r *agentRepository) Get(orgName, projName, agentName string) (*models.Agent, error) { ... }
```

---

## 6. Structured Logging

Use **`log/slog` exclusively**. Do not introduce `logrus`, `zap`, `zerolog`, or `fmt.Print` for logging.

```go
// Good
slog.InfoContext(ctx, "creating agent",
    "org", orgName,
    "project", projName,
    "agent", agentName,
)
slog.ErrorContext(ctx, "failed to create agent",
    "error", err,
    "org", orgName,
)

// Bad
fmt.Printf("creating agent %s\n", agentName)
log.Printf("error creating agent: %v", err)
```

### Log Level Guidelines

| Level | When to use |
|---|---|
| `Debug` | Fine-grained detail for local development |
| `Info` | Normal operations — resource created, request received |
| `Warn` | Unexpected but recoverable conditions |
| `Error` | Failures that affect the current request |

**Never log secrets, tokens, passwords, or PII at any log level.**

---

## 7. Dependency Injection (google/wire)

- All constructors must be registered in `wiring/` via Wire provider sets.
- `wiring.AppParams` is the root composition root — all controllers and top-level services live here.
- Do not use `init()` functions or global singletons for dependencies.
- Do not call constructors directly inside other constructors — let Wire manage the graph.

```go
// wiring/providers.go
var RepositorySet = wire.NewSet(
    repositories.NewAgentRepository,
    repositories.NewMonitorRepository,
    // ...
)

var ServiceSet = wire.NewSet(
    services.NewAgentService,
    services.NewMonitorService,
    // ...
)
```

---

## 8. HTTP Controllers

Controllers have exactly **one job per handler method**: parse input → validate → call one service method → write response.

```go
// controllers/agent_controller.go

type AgentController interface {
    CreateAgent(w http.ResponseWriter, r *http.Request)
    GetAgent(w http.ResponseWriter, r *http.Request)
    ListAgents(w http.ResponseWriter, r *http.Request)
    DeleteAgent(w http.ResponseWriter, r *http.Request)
}

func (c *agentController) CreateAgent(w http.ResponseWriter, r *http.Request) {
    var req models.CreateAgentRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        utils.WriteValidationErrorResponse(w, "invalid request body")
        return
    }
    if err := req.Validate(); err != nil {
        utils.WriteValidationErrorResponse(w, err.Error())
        return
    }

    agent, err := c.agentService.Create(r.Context(), req)
    if err != nil {
        // error translation — see Error Handling section
        return
    }

    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(agent.ToResponse())
}
```

**Forbidden in controllers:**
- Direct database calls
- Business logic (conditionals about domain state)
- Calls to more than one service (if you need two services, create a new service that composes them)

---

## 9. HTTP Middleware

Apply middleware in `api/` only. The **standard middleware chain**, in order:

```go
r.Use(middleware.RecovererOnPanic())
r.Use(middleware.CORS())
r.Use(middleware.AddCorrelationID())
r.Use(logger.RequestLogger())
// For authenticated routes:
r.Use(jwtassertion.Middleware)
```

Never apply middleware inside controllers or services. Custom middleware must live in `middleware/`.

---

## 10. Database Conventions (GORM)

### Model Template

```go
// models/agent.go
type Agent struct {
    UUID        uuid.UUID      `gorm:"column:id;primaryKey;type:uuid;default:gen_random_uuid()"`
    OrgName     string         `gorm:"column:org_name;not null"`
    ProjectName string         `gorm:"column:project_name;not null"`
    Name        string         `gorm:"column:name;not null"`
    DisplayName string         `gorm:"column:display_name"`
    Description string         `gorm:"column:description"`
    Properties  map[string]any `gorm:"type:jsonb;serializer:json"`
    CreatedAt   time.Time      `gorm:"column:created_at"`
    UpdatedAt   time.Time      `gorm:"column:updated_at"`
    DeletedAt   gorm.DeletedAt `gorm:"column:deleted_at;index"`
}
```

### Model Rules

- **UUIDs for all primary keys.** Use `gen_random_uuid()` as the DB default — never generate UUIDs in application code.
- **Always include `CreatedAt`, `UpdatedAt`, `DeletedAt`** on every entity model.
- **`gorm.DeletedAt` for soft deletes.** Never hard-delete entities.
- **JSONB for unstructured/extensible data.** Use `gorm:"type:jsonb;serializer:json"`.
- **Column names in `snake_case`** — always explicit via `gorm:"column:..."` tag.

### Repository Implementation Rules

```go
// Use Clauses for upserts — never check-then-insert
db.Clauses(clause.OnConflict{
    Columns:   []clause.Column{{Name: "org_name"}, {Name: "name"}},
    DoUpdates: clause.AssignmentColumns([]string{"display_name", "updated_at"}),
}).Create(&agent)

// Wrap multi-step writes in a transaction
func (r *agentRepository) CreateWithConfig(ctx context.Context, agent *models.Agent, config *models.AgentConfig) error {
    return r.RunInTransaction(ctx, func(tx *gorm.DB) error {
        if err := tx.Create(agent).Error; err != nil {
            return fmt.Errorf("create agent: %w", err)
        }
        config.AgentID = agent.UUID
        if err := tx.Create(config).Error; err != nil {
            return fmt.Errorf("create agent config: %w", err)
        }
        return nil
    })
}
```

### Migrations

- SQL files live exclusively in `db_migrations/`. No schema changes in Go code.
- Naming: `{timestamp}_{description}.sql` — e.g., `20240901120000_add_agent_table.sql`
- **Append-only.** Never modify a migration file that has been applied to any environment.

---

## 11. REST API Conventions

### OpenAPI First

**All API changes start with `agent-manager-service/docs/api_v1_openapi.yaml`.** Generate Go models from the spec. Do not write request/response structs by hand and sync them later.

### URL Hierarchy

```
/orgs/{orgName}
/orgs/{orgName}/projects/{projName}
/orgs/{orgName}/projects/{projName}/agents/{agentName}
/orgs/{orgName}/projects/{projName}/agents/{agentName}/model-configs
/orgs/{orgName}/gateways
```

- Path parameters: `camelCase` — `{orgName}`, not `{org_name}`.
- Resource names are **plural nouns**: `/agents`, `/gateways`, `/monitors`.
- Pagination query params are always `limit` (int) and `offset` (int).

### HTTP Method → Status Code

| Operation | Method | Success Code |
|---|---|---|
| Create | `POST` | `201 Created` |
| Read single | `GET` | `200 OK` |
| Read list | `GET` | `200 OK` |
| Full replace | `PUT` | `200 OK` |
| Partial update | `PATCH` | `200 OK` |
| Delete | `DELETE` | `204 No Content` |

### Response Shapes

```json
// Single resource
{ "name": "my-agent", "displayName": "My Agent", "createdAt": "..." }

// Paginated list
{ "items": [...], "total": 42, "limit": 10, "offset": 0 }

// Error
{ "code": "NOT_FOUND", "message": "agent 'my-agent' not found in project 'my-project'" }
```

---

## 12. Testing

### File & Function Naming

- Test files: `*_test.go`, co-located with the package or in `tests/` for integration.
- Test functions: `Test` + exact function name — `TestCreateAgent`, `TestListMonitors`.

### Table-Driven Tests (Required for 2+ cases)

```go
func TestCreateAgent(t *testing.T) {
    cases := []struct {
        name       string
        req        models.CreateAgentRequest
        setupMock  func(*mocks.AgentServiceMock)
        wantStatus int
    }{
        {
            name:       "success",
            req:        models.CreateAgentRequest{Name: "my-agent"},
            setupMock:  func(m *mocks.AgentServiceMock) { m.CreateFunc = ... },
            wantStatus: http.StatusCreated,
        },
        {
            name:       "conflict - agent already exists",
            setupMock:  func(m *mocks.AgentServiceMock) { m.CreateFunc = func(...) error { return repositories.ErrConflict } },
            wantStatus: http.StatusConflict,
        },
    }

    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            mock := &mocks.AgentServiceMock{}
            tc.setupMock(mock)
            // ... test body
            require.Equal(t, tc.wantStatus, recorder.Code)
        })
    }
}
```

### Assertions

- `require.*` — for assertions that must stop the test on failure (e.g., setup steps).
- `assert.*` — for assertions that should report but continue.
- Do not use bare `if err != nil { t.Fatal(...) }`.

### Mocking

Use **hand-crafted mock structs with function fields** — consistent with `clientmocks.OpenChoreoClientMock`:

```go
type AgentServiceMock struct {
    CreateFunc func(ctx context.Context, req models.CreateAgentRequest) (*models.Agent, error)
    GetFunc    func(ctx context.Context, orgName, projName, agentName string) (*models.Agent, error)
}

func (m *AgentServiceMock) Create(ctx context.Context, req models.CreateAgentRequest) (*models.Agent, error) {
    return m.CreateFunc(ctx, req)
}
```

Do not introduce `gomock` or `mockery`.

### Running Tests

```bash
make test       # against main DB
make dev-test   # against isolated test DB (use this locally)
```

---

## 13. Hard Rules — Never Do This

1. **No business logic in controllers.** Parse, validate, delegate, respond — nothing else.
2. **No direct DB queries in services.** All DB access goes through a repository interface.
3. **No `fmt.Print`, `log.Print`, or `logrus`/`zap`.** Use `slog` exclusively.
4. **No raw JSON error strings in HTTP handlers.** Use `utils.WriteErrorResponse`.
5. **No `http.Error`.** Use `utils.WriteErrorResponse` or `utils.WriteValidationErrorResponse`.
6. **No modifying existing SQL migration files.** Append new files only.
7. **No bypassing the OpenAPI spec.** Define endpoints in `api_v1_openapi.yaml` first.
8. **No global singletons or `init()` for dependencies.** Wire manages the graph.
9. **No logging secrets, tokens, or PII** at any log level.
10. **No ignoring errors.** Every `err != nil` is handled, wrapped, or returned.

---

*Part of the WSO2 Agent Manager AI coding standards. See also: [`amp-typescript.md`](./amp-typescript.md), [`amp-python.md`](./amp-python.md), [`amp-universal.md`](./amp-universal.md)*
