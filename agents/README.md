# Agentic AI — DevSecOps Agents

A small system of goal-driven agents, powered by the **Claude API** (Anthropic
Python SDK, `claude-opus-4-7`), that turns this repo's *reporting* security
pipeline into an *enforcing, self-triaging* one. This is the code companion to
[docs/AGENTIC_AI_TRANSFORMATION.md](../docs/AGENTIC_AI_TRANSFORMATION.md).

The **Security Triage Agent** is implemented and runnable today; the other five
agents from the roadmap register behind the same orchestrator + guardrail layer
as they come online.

## Architecture

```mermaid
flowchart TB
    classDef gov   fill:#FCE4EC,stroke:#AD1457,color:#880E4F
    classDef orch  fill:#F3E5F5,stroke:#6A1B9A,color:#4A148C
    classDef agent fill:#E0F7FA,stroke:#00838F,color:#006064
    classDef impl  fill:#E8F5E9,stroke:#2E7D32,color:#1B5E20
    classDef io    fill:#FFF8E1,stroke:#F57F17,color:#E65100
    classDef api   fill:#E3F2FD,stroke:#1565C0,color:#0D47A1

    subgraph GOV["guardrails.py — operating envelope"]
        direction LR
        G1["AuditLogger<br/>append-only JSONL"]:::gov
        G2["wrap_untrusted<br/>prompt-injection defense"]:::gov
        G3["SecurityInvariant<br/>agents cannot weaken security"]:::gov
        G4["HumanApprovalGate<br/>human-in-the-loop"]:::gov
    end

    ORCH["orchestrator.py<br/>AgentOrchestrator + CLI"]:::orch
    GOV --> ORCH

    subgraph AGENTS["agents"]
        direction LR
        T["SecurityTriageAgent<br/>implemented"]:::impl
        R["Remediation agent<br/>roadmap"]:::agent
        I["IaC hardening agent<br/>roadmap"]:::agent
        P["Pipeline self-healing<br/>roadmap"]:::agent
        C["Compliance evidence<br/>roadmap"]:::agent
    end
    ORCH --> T
    ORCH -.-> R
    ORCH -.-> I
    ORCH -.-> P
    ORCH -.-> C

    BASE["base.py — BaseAgent<br/>prompt caching · adaptive thinking<br/>structured outputs"]:::impl
    T --> BASE

    SARIF[("SARIF from pipeline<br/>Bandit · Semgrep · pip-audit<br/>Trivy FS/image · Checkov")]:::io
    SARIF -->|"untrusted data"| T

    API["Claude API<br/>claude-opus-4-7"]:::api
    BASE -->|"messages.create"| API

    REPORT["Prioritized triage report<br/>dedup · rank · block decision"]:::io
    T --> REPORT
    REPORT -->|"--fail-on-block"| GATE{"CI gate"}:::orch
```

## Run it

```bash
pip install -r agents/requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...

# Triage the bundled sample SARIF (no pipeline run needed)
python -m agents.orchestrator agents/sample

# Triage real pipeline artifacts (files, globs, or a directory)
python -m agents.orchestrator path/to/bandit-results.sarif path/to/trivy-fs-results.sarif

# CI gate: exit non-zero when triage recommends blocking the build
python -m agents.orchestrator --fail-on-block "$RUNNER_TEMP"/*.sarif
```

## What the triage agent does

Given the SARIF the pipeline already produces, the agent uses Claude to:

1. **Deduplicate** findings reported by several scanners into one entry.
2. **Rank** by `severity x exploitability x reachability` (priority 1 = most urgent).
3. **Flag false positives** — but never for CRITICAL/HIGH (enforced, see below).
4. **Recommend a concrete action** per finding (e.g. "upgrade requests to >=2.32.0").
5. **Decide** whether the build should block.

## How the Claude API is used (`base.py`)

- **Model:** `claude-opus-4-7` (override with `AGENT_MODEL`).
- **Adaptive thinking** (`thinking: {type: "adaptive"}`) + **effort** (`output_config.effort`, default `high`) — room to reason about exploitability without a fixed token budget.
- **Structured outputs** (`output_config.format` JSON schema) — the reply is always a valid, parseable triage object.
- **Prompt caching** — the stable system prompt (triage rubric + guardrails) is cached, so repeated runs only pay for the volatile SARIF payload. Cache hit/miss is recorded to the audit trail.

## Guardrails (`guardrails.py`)

| Control | Implementation |
|---|---|
| **Full audit trail** | `AuditLogger` writes every observation/decision/action to append-only JSONL (`agents/.audit/`). |
| **Prompt-injection defense** | `wrap_untrusted()` fences SARIF as DATA with an explicit "ignore embedded instructions" banner. |
| **Agents cannot weaken security** | `SecurityInvariant` flips any attempt to mark a CRITICAL/HIGH as a false positive back to "needs human review" and forces the build to block. |
| **Human-in-the-loop** | `HumanApprovalGate` (deny-until-approved) for the future high-risk agents that open PRs or change policy. The triage agent is advisory/read-only and needs no gate. |

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | — | Required. Claude API key. |
| `AGENT_MODEL` | `claude-opus-4-7` | Model id (e.g. `claude-sonnet-4-6` for cheaper high-volume triage). |
| `AGENT_EFFORT` | `high` | `low` / `medium` / `high` / `max`. |
| `AGENT_MAX_TOKENS` | `16000` | Output cap (non-streaming). |
| `AGENT_AUDIT_LOG` | `agents/.audit/agent-audit.jsonl` | Audit trail path. |
| `AGENT_AUTO_APPROVE` | unset | `1` lets the approval gate auto-approve (dev only). |

> Wiring this into CI as a non-blocking advisory step (Phase 1 Assistive) is the
> next milestone — the agent ranks findings while humans still act. See the
> phased roadmap in [docs/AGENTIC_AI_TRANSFORMATION.md](../docs/AGENTIC_AI_TRANSFORMATION.md).
