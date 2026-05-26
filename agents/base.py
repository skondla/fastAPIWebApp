"""
BaseAgent — shared Claude API plumbing for every agent.

Centralizes: client construction, prompt caching, adaptive thinking + effort,
structured-output (JSON-schema) calls, and audit logging. Subclasses supply a
stable system prompt (cached) and call `complete_json()` with per-request data.
"""

from __future__ import annotations

import json
from typing import Any

from . import config
from .guardrails import AuditLogger


class AgentError(RuntimeError):
    """Raised when the model cannot produce a usable structured result."""


class BaseAgent:
    """Base class wrapping the Anthropic SDK with the project's defaults.

    The ``anthropic`` package is imported lazily inside ``__init__`` so that the
    pure-Python helpers (e.g. SARIF parsing) can be imported and unit-tested
    without the SDK installed — only constructing an agent needs it.
    """

    #: Human-readable agent name, used in the audit trail.
    name: str = "base-agent"

    #: Stable instructions — cached as a prompt prefix across runs.
    system_prompt: str = "You are a helpful agent."

    def __init__(self, audit: AuditLogger | None = None) -> None:
        try:
            import anthropic
        except ModuleNotFoundError as exc:
            raise AgentError(
                "The 'anthropic' package is required to run an agent. Install it with:\n"
                "    pip install -r agents/requirements.txt"
            ) from exc

        # The SDK reads ANTHROPIC_API_KEY from the environment. Fail clearly if absent.
        try:
            self._client = anthropic.Anthropic()
        except Exception as exc:  # noqa: BLE001 - surface a friendly message
            raise AgentError(
                f"Could not initialize the Anthropic client. Set ${config.API_KEY_ENV}. ({exc})"
            ) from exc
        self.audit = audit or AuditLogger()

    # ──────────────────────────────────────────────────────────────────────────
    def complete_json(self, user_content: str, schema: dict[str, Any]) -> dict[str, Any]:
        """
        Run one structured-output request and return the parsed JSON object.

        - System prompt is cached (prompt caching) so repeated runs only pay for
          the volatile per-request content.
        - Adaptive thinking + effort give the model room to reason about
          exploitability/reachability without a fixed token budget.
        - output_config.format constrains the reply to the supplied JSON schema.
        """
        response = self._client.messages.create(
            model=config.MODEL,
            max_tokens=config.MAX_TOKENS,
            thinking={"type": "adaptive"},
            output_config={
                "effort": config.EFFORT,
                "format": {"type": "json_schema", "schema": schema},
            },
            # Cache the stable instructions; volatile data rides in `messages`.
            system=[
                {
                    "type": "text",
                    "text": self.system_prompt,
                    "cache_control": {"type": "ephemeral"},
                }
            ],
            messages=[{"role": "user", "content": user_content}],
        )

        # Observability: record cache effectiveness + token usage.
        usage = response.usage
        self.audit.record(
            self.name,
            "model.call",
            model=config.MODEL,
            stop_reason=response.stop_reason,
            input_tokens=usage.input_tokens,
            output_tokens=usage.output_tokens,
            cache_read_input_tokens=getattr(usage, "cache_read_input_tokens", 0),
            cache_creation_input_tokens=getattr(usage, "cache_creation_input_tokens", 0),
        )

        if response.stop_reason == "refusal":
            detail = getattr(response, "stop_details", None)
            raise AgentError(f"Model refused the request: {detail}")
        if response.stop_reason == "max_tokens":
            raise AgentError(
                "Output truncated (max_tokens). Reduce input batch size or raise AGENT_MAX_TOKENS."
            )

        text = next((b.text for b in response.content if b.type == "text"), None)
        if not text:
            raise AgentError("Model returned no text block to parse.")
        try:
            return json.loads(text)
        except json.JSONDecodeError as exc:  # output_config.format makes this rare
            raise AgentError(f"Could not parse structured output: {exc}") from exc
