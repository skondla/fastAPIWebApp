"""
Agentic AI for the fastAPIWebApp DevSecOps pipeline.

A small system of goal-driven agents — powered by the Claude API — that turn the
pipeline's *reporting* security stages into an *enforcing, self-triaging* one.

See docs/AGENTIC_AI_TRANSFORMATION.md for the architecture and roadmap.
"""

__all__ = ["config", "guardrails", "base", "triage_agent", "orchestrator"]
