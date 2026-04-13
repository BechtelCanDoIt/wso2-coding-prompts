# WSO2 Enterprise — Python Coding Standard

> **Scope:** All WSO2 Python libraries and services across all repositories.
> Python is not WSO2's primary language — it appears in AI/ML tooling, evaluation SDKs,
> instrumentation libraries, and automation scripts. These standards reflect that context.
> Project-specific guides layer on top and win on conflict.

---

## 1. When Python Is Appropriate at WSO2

Use Python for:
- AI/ML evaluation pipelines and SDKs
- OpenTelemetry instrumentation wrappers for Python AI frameworks
- Automation and scripting that integrates with the platform
- Data analysis tooling

Use Go or Java for production services, APIs, and anything requiring high throughput or OSGi integration.

---

## 2. Python Version

Target **Python 3.10+** as the minimum supported version. Test against 3.10, 3.11, 3.12, and 3.13 in CI. Do not use features that require 3.12+ without a corresponding version guard and CI matrix entry.

---

## 3. Package and Module Structure

```
src/
└── <package_name>/       # e.g., amp_evaluation
    ├── __init__.py       # Define the public API here — explicit exports only
    ├── models.py         # Pydantic models and data structures
    ├── config.py         # pydantic-settings configuration classes
    └── <subpackage>/
        ├── __init__.py
        └── ...

tests/
├── conftest.py           # Shared fixtures
└── test_*.py             # Test modules — mirror the src structure
```

- Source code lives under `src/` — use `src` layout for all new packages.
- Public API is defined explicitly in the root `__init__.py`. Only what is imported there is considered stable.
- Never import from `tests/` in source code.

---

## 4. Naming Conventions

| Construct | Convention | Example |
|---|---|---|
| Packages and modules | `snake_case` | `amp_evaluation`, `trace_fetcher` |
| Classes | `PascalCase` | `BaseEvaluator`, `TraceConfig` |
| Functions and methods | `snake_case` | `discover_evaluators`, `fetch_trace` |
| Private / internal members | Leading `_` | `_parse_trace`, `_framework_classes` |
| Constants | `UPPER_SNAKE_CASE` | `DEFAULT_TIMEOUT_MS`, `AMP_OTEL_ENDPOINT` |
| Environment variable names | `UPPER_SNAKE_CASE` with product prefix | `AMP_API_KEY`, `AMP_TRACE_ENDPOINT` |

---

## 5. Type Hints

All public function signatures must be fully annotated — parameters and return type.

```python
# Good
def fetch_trace(trace_id: str, org_name: str, timeout_ms: int = 5000) -> Trace | None:
    ...

# Bad — no annotations
def fetch_trace(trace_id, org_name):
    ...
```

### Rules
- Use `from __future__ import annotations` at the top of any file with forward references.
- Use `X | Y` union syntax (Python 3.10+) in preference to `Optional[X]` or `Union[X, Y]`.
- Use `Any` from `typing` explicitly and sparingly — only at untyped third-party boundaries, with a comment explaining why.
- Run `mypy` in CI. Do not use `# type: ignore` without a comment referencing a tracking issue.

---

## 6. Configuration Management

Use **`pydantic-settings`** for all configuration that is loaded from environment variables or `.env` files.

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class TraceConfig(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="AMP_TRACE_",   # reads AMP_TRACE_ENDPOINT, AMP_TRACE_TIMEOUT_MS, etc.
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    endpoint: str
    timeout_ms: int = 5000
    api_key: str | None = None
```

### Rules
- All environment variable names use the product prefix (`AMP_`, `WSO2_`, etc.).
- Define variable names as constants alongside the config class.
- Never read `os.environ` directly in business logic — always go through a config class.

---

## 7. Pydantic Data Models

Use **Pydantic v2** for all data models that cross network or file boundaries.

```python
from pydantic import BaseModel, ConfigDict, field_validator

class EvalResult(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    score: float
    explanation: str
    skipped: bool = False
    skip_reason: str | None = None

    @field_validator("score")
    @classmethod
    def score_must_be_normalized(cls, v: float) -> float:
        if not 0.0 <= v <= 1.0:
            raise ValueError(f"score must be in [0.0, 1.0], got {v}")
        return v
```

### Rules
- Every model must have `model_config = ConfigDict(...)`.
- Use `frozen=True` for value objects that should not be mutated after creation.
- Use `extra="forbid"` to fail loudly on unexpected fields.
- Validators raise `ValueError` with a human-readable message — never bare `Exception`.

---

## 8. Error Handling

```python
# Good — specific exception type, preserves cause
try:
    result = api_client.get_trace(trace_id)
except requests.Timeout as e:
    raise TraceRetrievalError(f"Timed out fetching trace {trace_id}") from e
except requests.HTTPError as e:
    raise TraceRetrievalError(f"HTTP error fetching trace {trace_id}: {e.response.status_code}") from e

# Bad — bare except swallows everything
try:
    result = api_client.get_trace(trace_id)
except:
    pass
```

### Rules
- Never use bare `except:` — always specify the exception type.
- Always use `raise ... from e` to preserve the exception chain.
- Define custom exception classes when callers need to distinguish failure modes.
- In bootstrapping/startup code where a crash would harm the host process, catch `Exception` broadly, log to `stderr`, and continue — document why explicitly.

---

## 9. Logging

Use the standard `logging` module — not `print()`.

```python
import logging

logger = logging.getLogger(__name__)

def process_trace(trace_id: str) -> None:
    logger.debug("Processing trace %s", trace_id)
    try:
        ...
    except TraceRetrievalError as e:
        logger.error("Failed to process trace %s: %s", trace_id, e, exc_info=True)
        raise
```

### Rules
- Get the logger with `logging.getLogger(__name__)` in every module — never use the root logger directly.
- Use `%s` style formatting in log calls — not f-strings. This defers string formatting when the log level is disabled.
- Pass `exc_info=True` to `logger.error()` when logging exceptions to include the traceback.
- Never log secrets, tokens, API keys, or PII.
- CLI tools and bootstrap code may write to `sys.stderr` for error reporting — but library code must use `logging`.

---

## 10. Testing

### Framework
**`pytest`** exclusively. Do not use `unittest.TestCase`.

### Structure
```
tests/
├── conftest.py            # Shared fixtures and test utilities
├── test_models.py         # Tests for models.py
├── test_config.py         # Tests for config.py
└── <subpackage>/
    └── test_*.py          # Mirror source structure
```

### Naming
- Test files: `test_<module>.py`
- Test functions: `test_<behaviour_being_tested>`
- Test classes: `Test<Subject>` (when grouping is useful)

```python
class TestEvalResult:
    def test_score_at_zero_is_valid(self):
        result = EvalResult(score=0.0, explanation="no match")
        assert result.score == 0.0

    def test_score_above_one_raises(self):
        with pytest.raises(ValidationError):
            EvalResult(score=1.5, explanation="over limit")

    def test_skip_factory_sets_skipped_flag(self):
        result = EvalResult.skip("missing data")
        assert result.skipped
        assert result.skip_reason == "missing data"
```

### Coverage
Run with coverage:
```bash
pytest --cov=src --cov-report=term-missing --cov-report=html
```
CI must fail if coverage falls below the project-defined threshold.

### Fixtures
- Shared fixtures in `conftest.py`.
- Prefer factory fixtures over large data objects.

```python
# conftest.py
@pytest.fixture
def make_trace():
    def _factory(llm_spans=None, tool_spans=None, duration_ms=100):
        return Trace(llm_spans=llm_spans or [], tool_spans=tool_spans or [], duration_ms=duration_ms)
    return _factory
```

---

## 11. Tooling

| Tool | Purpose | Config |
|---|---|---|
| `black` | Formatter | `pyproject.toml` |
| `ruff` | Linter | `pyproject.toml` |
| `mypy` | Static type checker | `pyproject.toml` |
| `pytest` + `pytest-cov` | Test runner + coverage | `pyproject.toml` |
| `build` + `twine` | Package build and publish | CI only |

All tool configuration lives in `pyproject.toml`. Do not add `setup.cfg`, `.flake8`, or `mypy.ini` as separate files.

```toml
[tool.black]
line-length = 100

[tool.ruff]
line-length = 100
select = ["E", "F", "I", "UP", "B"]

[tool.mypy]
strict = true
ignore_missing_imports = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--strict-markers"
```

---

## 12. Packaging

```toml
# pyproject.toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "amp-evaluation"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "pydantic>=2.0",
    "pydantic-settings>=2.0",
    "requests>=2.28",
    "opentelemetry-api>=1.20",
]

[project.optional-dependencies]
llm-judge = ["deepeval>=1.0", "litellm>=1.0"]
dev = ["pytest", "pytest-cov", "black", "ruff", "mypy"]
```

- Use `pyproject.toml` with `hatchling` for all new packages.
- Separate optional heavy dependencies (e.g., ML libraries) into `[project.optional-dependencies]` groups.
- Pin minimum versions (`>=`), not exact versions (`==`), in library `dependencies`.

---

*WSO2 Python base standard. See project-specific guide for overrides and additions.*
