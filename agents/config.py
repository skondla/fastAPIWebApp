"""Central configuration for the DevSecOps agents."""

from __future__ import annotations

import os

# ─── Model ───────────────────────────────────────────────────────────────────
# Default to the most capable model. Override with AGENT_MODEL if you want a
# cheaper tier for high-volume triage (e.g. claude-sonnet-4-6 / claude-haiku-4-5).
MODEL: str = os.environ.get("AGENT_MODEL", "claude-opus-4-7")

# Effort controls thinking depth + token spend (output_config.effort).
# "high" is a good balance for security reasoning; "max" for correctness-critical runs.
EFFORT: str = os.environ.get("AGENT_EFFORT", "high")

# Non-streaming cap — keeps requests under the SDK's HTTP-timeout guard.
MAX_TOKENS: int = int(os.environ.get("AGENT_MAX_TOKENS", "16000"))

# ─── Identity / trust boundary ───────────────────────────────────────────────
API_KEY_ENV = "ANTHROPIC_API_KEY"

# Where the agents write their append-only audit trail (guardrail: full auditability).
AUDIT_LOG_PATH: str = os.environ.get("AGENT_AUDIT_LOG", "agents/.audit/agent-audit.jsonl")

# Severities an agent may NEVER silently downgrade or suppress. Any attempt to
# mark one of these as a false positive is escalated for human review instead of
# being accepted — enforces "agents cannot weaken security".
PROTECTED_SEVERITIES = frozenset({"critical", "high"})
