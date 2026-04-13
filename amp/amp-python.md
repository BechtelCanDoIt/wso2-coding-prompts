# amp — Python Coding Standard

> **Applies to:** `libs/amp-evaluation/` and `libs/amp-instrumentation/`
> **Read first:** [`wso2-python.md`](./wso2-python.md) — this file extends and overrides it.
> **Stack:** Python 3.10+, Pydantic v2, pydantic-settings, OpenTelemetry, Traceloop SDK, pytest, black, ruff, mypy

---

## Overrides from `wso2-python.md`

| Topic | WSO2 Default | amp Override |
|---|---|---|
| Pydantic version | v2 | v2 ✅ same |
| Type checker | mypy | mypy ✅ same |
| Config env prefix | product-specific | `AMP_` and `AMP_TRACE_` |
| Bootstrapping error handling | log + continue | `try/except Exception` → `sys.stderr` + continue (never crash host app) |
| Evaluation return on missing data | raise exception | **Return `EvalResult.skip(reason)` — never score=0.0** |

---

## Table of Contents

1. [Package Structure](#1-package-structure)
2. [Evaluation Level — The Type Hint Mechanic](#2-evaluation-level--the-type-hint-mechanic)
3. [Evaluator Patterns (amp-evaluation)](#3-evaluator-patterns-amp-evaluation)
4. [Pydantic Conventions](#4-pydantic-conventions)
5. [Configuration (pydantic-settings)](#5-configuration-pydantic-settings)
6. [Instrumentation Bootstrap (amp-instrumentation)](#6-instrumentation-bootstrap-amp-instrumentation)
7. [Testing](#7-testing)
8. [Hard Rules — Never Do This](#8-hard-rules--never-do-this)

---

## 1. Package Structure

### `amp-evaluation`

```
src/amp_evaluation/
├── __init__.py           # Public API: BaseEvaluator, EvalResult, @evaluator, @llm_judge, Trace, AgentTrace, LLMSpan
├── models.py             # EvalResult, EvaluatorInfo, RunResult
├── registry.py           # @evaluator / @llm_judge decorator registration + discover_evaluators()
├── runner.py             # Evaluation runner / execution orchestration
├── config.py             # AgentConfig, TraceConfig, LLMJudgeConfig (pydantic-settings)
├── evaluators/
│   ├── __init__.py
│   ├── base.py           # BaseEvaluator (ABC), LLMAsJudgeEvaluator
│   ├── params.py         # Param descriptor for configurable evaluator parameters
│   └── builtins/         # Built-in evaluators shipped with the SDK
├── trace/
│   ├── __init__.py
│   ├── models.py         # Trace, AgentTrace, LLMSpan, ToolSpan, AmpSpanData
│   ├── parser.py         # Trace parsing from raw OpenTelemetry data
│   └── fetcher.py        # TraceFetcher — retrieves traces from the platform API
├── aggregators/          # Multi-evaluator result aggregation strategies
└── dataset/              # Dataset loading and management

tests/
├── conftest.py
├── test_models.py
├── evaluators/
│   └── test_*.py
└── trace/
    └── test_*.py
```

### `amp-instrumentation`

```
src/amp_instrumentation/
├── __init__.py
├── _bootstrap/
│   ├── sitecustomize.py   # Auto-executed at Python startup via PYTHONPATH injection
│   └── initialization.py  # Core Traceloop SDK initialization + env var constants
└── cli/
    └── main.py            # amp-instrument CLI entry point

tests/
├── conftest.py
├── test_cli.py
└── test_initialization.py
```

---

## 2. Evaluation Level — The Type Hint Mechanic

This is the most important amp-Python-specific pattern. **Do not break it.**

The evaluation framework introspects the **type hint of the first parameter** of `evaluate()` to determine the granularity at which the evaluator is invoked:

| First parameter type | Called once per… |
|---|---|
| `trace: Trace` | Full multi-agent trace |
| `agent: AgentTrace` | Each agent within a trace |
| `llm_span: LLMSpan` | Each individual LLM call span |

```python
from amp_evaluation.trace.models import Trace, AgentTrace, LLMSpan
from amp_evaluation import EvalResult

# Trace-level — receives the full picture of one agent run
def evaluate(self, trace: Trace) -> EvalResult: ...

# Agent-level — one invocation per agent in the trace
def evaluate(self, agent: AgentTrace) -> EvalResult: ...

# LLM span-level — one invocation per LLM call
def evaluate(self, llm_span: LLMSpan) -> EvalResult: ...
```

The parameter **name** (`trace`, `agent`, `llm_span`) does not matter — only the **type** does.
Use the canonical names above for readability. **Changing the type hint changes the evaluation scope — treat it as a breaking API change.**

---

## 3. Evaluator Patterns (`amp-evaluation`)

### Always Register with Decorators

Use `@evaluator` (function-based) or `@llm_judge` (class-based). Never subclass `BaseEvaluator` and register manually.

```python
from amp_evaluation import evaluator, llm_judge, EvalResult
from amp_evaluation.trace.models import Trace, LLMSpan
from amp_evaluation.evaluators import LLMAsJudgeEvaluator

# --- Function-based evaluator ---
@evaluator(
    name="tool-call-success",
    description="Checks whether all tool calls in the trace completed without errors"
)
def tool_call_success(trace: Trace) -> EvalResult:
    if not trace.tool_spans:
        return EvalResult.skip("no tool calls found in trace")
    failed = [s for s in trace.tool_spans if s.status == "error"]
    if not failed:
        return EvalResult(score=1.0, explanation="all tool calls succeeded")
    return EvalResult(
        score=0.0,
        explanation=f"{len(failed)} of {len(trace.tool_spans)} tool call(s) failed: "
                    f"{[s.name for s in failed]}"
    )

# --- LLM-as-judge evaluator ---
@llm_judge(
    name="response-relevance",
    description="Scores how relevant the agent response is to the user query"
)
class ResponseRelevanceEvaluator(LLMAsJudgeEvaluator):
    prompt_template: str = """
    User query: {query}
    Agent response: {response}

    Score relevance 0.0 (irrelevant) to 1.0 (perfectly relevant).
    Return JSON: {{"score": <float>, "explanation": "<string>"}}
    """
```

### Configurable Parameters via `Param`

Use `Param` descriptors for any threshold, prompt, or value that should be user-configurable. Never hardcode them.

```python
from amp_evaluation.evaluators.params import Param

@evaluator(name="latency-budget")
def latency_budget(
    trace: Trace,
    max_ms: float = Param(default=2000.0, description="Max acceptable total latency in ms"),
    warn_ms: float = Param(default=1000.0, description="Latency at which to flag a warning"),
) -> EvalResult:
    if trace.duration_ms <= warn_ms:
        return EvalResult(score=1.0, explanation=f"{trace.duration_ms}ms — within budget")
    if trace.duration_ms <= max_ms:
        return EvalResult(score=0.5, explanation=f"{trace.duration_ms}ms — approaching limit of {max_ms}ms")
    return EvalResult(score=0.0, explanation=f"{trace.duration_ms}ms — exceeds budget of {max_ms}ms")
```

### The Skip Pattern — Core Rule

Return `EvalResult.skip(reason)` when required data is absent. **`score=0.0` means the agent performed poorly. `skipped=True` means the evaluation could not run.** These are not the same thing.

```python
# Good — communicates inability to evaluate
if not trace.llm_spans:
    return EvalResult.skip("no LLM spans found — evaluator requires at least one LLM call")

# Bad — makes a poor agent look the same as a missing-data scenario
if not trace.llm_spans:
    return EvalResult(score=0.0, explanation="no spans")
```

### Dynamic Evaluator Loading

The evaluation job loads user-supplied evaluators dynamically via `exec()`. Files loaded this way must:
- Have no import-time side effects.
- Export either a `@evaluator`-decorated function or a `BaseEvaluator` subclass at module level.
- Use absolute imports — the file is `exec`'d in a fresh namespace, not imported as a module.

---

## 4. Pydantic Conventions

amp uses **Pydantic v2**. These patterns extend the WSO2 baseline.

```python
from pydantic import BaseModel, ConfigDict, field_validator

class EvalResult(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    score: float
    explanation: str
    skipped: bool = False
    skip_reason: str | None = None

    @classmethod
    def skip(cls, reason: str) -> "EvalResult":
        """Use instead of score=0.0 when an evaluator cannot produce a meaningful score."""
        return cls(score=0.0, explanation="", skipped=True, skip_reason=reason)

    @field_validator("score")
    @classmethod
    def score_must_be_normalized(cls, v: float) -> float:
        if not 0.0 <= v <= 1.0:
            raise ValueError(f"score must be in [0.0, 1.0], got {v}")
        return v
```

### LLM Judge Output

Always validate LLM responses via `JudgeOutput`. Never parse the JSON manually.

```python
class JudgeOutput(BaseModel):
    model_config = ConfigDict(extra="ignore")  # LLMs add extra fields — tolerate them
    score: float
    explanation: str

    @field_validator("score")
    @classmethod
    def score_range(cls, v: float) -> float:
        if not 0.0 <= v <= 1.0:
            raise ValueError(f"judge score {v} out of [0.0, 1.0]")
        return v

# In LLMAsJudgeEvaluator
try:
    output = JudgeOutput.model_validate_json(llm_response_text)
except (ValidationError, ValueError) as e:
    return EvalResult.skip(f"invalid judge output: {e}")
```

---

## 5. Configuration (`pydantic-settings`)

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class TraceConfig(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="AMP_TRACE_",
        env_file=".env",
        extra="ignore",
    )
    endpoint: str
    api_key: str | None = None
    timeout_ms: int = 5000

class LLMJudgeConfig(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="AMP_")
    judge_model: str = "gpt-4o"
    judge_temperature: float = 0.0
```

### amp Environment Variable Registry

| Variable | Component | Purpose |
|---|---|---|
| `AMP_OTEL_ENDPOINT` | instrumentation | OTLP trace export endpoint |
| `AMP_SERVICE_NAME` | instrumentation | Service name for spans |
| `AMP_API_KEY` | evaluation | Platform API key |
| `AMP_TRACE_ENDPOINT` | evaluation | Trace fetch endpoint |
| `AMP_TRACE_TIMEOUT_MS` | evaluation | Trace fetch timeout |

Never read these via `os.environ` directly in business logic — always go through a config class.

---

## 6. Instrumentation Bootstrap (`amp-instrumentation`)

### The `sitecustomize` Mechanic

When `_bootstrap/` is on `PYTHONPATH`, Python automatically executes `sitecustomize.py` before user code runs. This is the mechanism for zero-code instrumentation.

```python
# amp_instrumentation/_bootstrap/sitecustomize.py
# AUTO-EXECUTED by Python at startup. Must never crash the host application.

import sys

try:
    from amp_instrumentation._bootstrap.initialization import initialize_instrumentation
    initialize_instrumentation()
except Exception as e:  # noqa: BLE001 — intentionally broad; bootstrap must never kill the app
    print(
        f"[amp-instrumentation] failed to initialize (continuing without instrumentation): {e}",
        file=sys.stderr,
    )
```

### CLI Contract

The CLI has exactly one job: inject `_bootstrap/` into `PYTHONPATH` and delegate.

```python
# amp_instrumentation/cli/main.py

import os
import subprocess
import sys
from pathlib import Path

def cli() -> None:
    args = sys.argv[1:]
    if not args:
        print("Usage: amp-instrument <command> [args...]", file=sys.stderr)
        sys.exit(1)

    bootstrap_dir = str(Path(__file__).parent.parent / "_bootstrap")
    env = os.environ.copy()
    env["PYTHONPATH"] = f"{bootstrap_dir}{os.pathsep}{env.get('PYTHONPATH', '')}"

    result = subprocess.run(args, env=env)
    sys.exit(result.returncode)
```

No instrumentation logic belongs here. Only environment manipulation and process delegation.

### Environment Variable Constants

All env var names are module-level constants in `initialization.py`:

```python
# amp_instrumentation/_bootstrap/initialization.py
AMP_OTEL_ENDPOINT = "AMP_OTEL_ENDPOINT"
AMP_SERVICE_NAME  = "AMP_SERVICE_NAME"
AMP_API_KEY       = "AMP_API_KEY"
```

---

## 7. Testing

### Every Evaluator Needs Three Test Cases Minimum

1. **Happy path** — evaluator scores correctly when data is present and good.
2. **Failure path** — evaluator scores `0.0` when data is present and bad.
3. **Skip path** — evaluator returns `EvalResult.skip(...)` when required data is absent.

```python
class TestToolCallSuccess:

    def test_scores_one_when_all_succeed(self, make_trace):
        trace = make_trace(tool_spans=[ToolSpan(name="search", status="ok")])
        result = tool_call_success(trace)
        assert result.score == 1.0
        assert not result.skipped

    def test_scores_zero_when_any_fail(self, make_trace):
        trace = make_trace(tool_spans=[ToolSpan(name="search", status="error")])
        result = tool_call_success(trace)
        assert result.score == 0.0
        assert not result.skipped

    def test_skips_when_no_tool_calls(self, make_trace):
        trace = make_trace(tool_spans=[])
        result = tool_call_success(trace)
        assert result.skipped
        assert result.skip_reason is not None
```

### Instrumentation Tests Must Prove Resilience

```python
def test_bootstrap_failure_does_not_raise(monkeypatch):
    """Simulate init failure — the host app must continue regardless."""
    monkeypatch.setattr(
        "amp_instrumentation._bootstrap.initialization.initialize_instrumentation",
        lambda: exec("raise RuntimeError('simulated failure')")
    )
    import importlib
    import amp_instrumentation._bootstrap.sitecustomize  # noqa — must not raise
```

### Shared Fixtures in `conftest.py`

```python
# tests/conftest.py
import pytest
from amp_evaluation.trace.models import Trace, LLMSpan, ToolSpan

@pytest.fixture
def make_trace():
    def _factory(
        llm_spans: list[LLMSpan] | None = None,
        tool_spans: list[ToolSpan] | None = None,
        duration_ms: float = 100.0,
    ) -> Trace:
        return Trace(
            llm_spans=llm_spans or [],
            tool_spans=tool_spans or [],
            duration_ms=duration_ms,
        )
    return _factory
```

---

## 8. Hard Rules — Never Do This

1. **Never return `EvalResult(score=0.0, ...)` when data is absent.** Use `EvalResult.skip(reason)`.
2. **Never change a type hint on `evaluate()`'s first parameter without treating it as a breaking change.** It changes evaluation scope.
3. **Never add logic to the `amp-instrument` CLI** beyond `PYTHONPATH` injection and subprocess delegation.
4. **Never let `sitecustomize.py` raise an uncaught exception.** The host application must always start.
5. **Never use `print()` in library code.** Use `logging.getLogger(__name__)`. Only `sys.stderr` in CLI/bootstrap error paths.
6. **Never use `exec()` outside the evaluation-job dynamic loader pattern.**
7. **Never hardcode thresholds, prompts, or model names.** Use `Param` descriptors and config classes.
8. **Never use bare `except:`.** Catch a specific type, or `Exception` with a `# noqa: BLE001` and a comment.
9. **Never use `unittest.TestCase`.** Use plain pytest.
10. **Never read `os.environ` directly in business logic.** All config flows through pydantic-settings classes.

---

*amp Python guide. Extends [`wso2-python.md`](./wso2-python.md).*
*See also: [`amp-go.md`](./amp-go.md) · [`amp-typescript.md`](./amp-typescript.md) · [`amp-universal.md`](./amp-universal.md)*
