"""
Agent Orchestrator — coordinates the DevSecOps agents and is the CLI entrypoint.

Today it runs the Security Triage Agent over SARIF artifacts. The remediation,
IaC-hardening, policy/secrets, pipeline-self-healing, and compliance-evidence
agents register here as they come online (see docs/AGENTIC_AI_TRANSFORMATION.md).

Usage:
    export ANTHROPIC_API_KEY=sk-ant-...
    pip install -r agents/requirements.txt

    # Point it at SARIF files or a directory of them
    python -m agents.orchestrator agents/sample
    python -m agents.orchestrator path/to/bandit-results.sarif path/to/trivy-fs-results.sarif

    # In CI: exit non-zero when triage recommends blocking the build
    python -m agents.orchestrator --fail-on-block "$RUNNER_TEMP"/*.sarif
"""

from __future__ import annotations

import argparse
import glob
import os
import sys

from .base import AgentError
from .guardrails import AuditLogger
from .triage_agent import SecurityTriageAgent, TriageReport


def _resolve_sarif(paths: list[str]) -> list[str]:
    """Expand directories and globs into a flat list of *.sarif files."""
    resolved: list[str] = []
    for p in paths:
        if os.path.isdir(p):
            resolved.extend(sorted(glob.glob(os.path.join(p, "**", "*.sarif"), recursive=True)))
        elif any(ch in p for ch in "*?["):
            resolved.extend(sorted(glob.glob(p, recursive=True)))
        else:
            resolved.append(p)
    # De-dupe while preserving order.
    seen: set[str] = set()
    return [x for x in resolved if not (x in seen or seen.add(x))]


def _print_report(report: TriageReport) -> None:
    print("\n" + "=" * 78)
    print("  SECURITY TRIAGE REPORT")
    print("=" * 78)
    print(f"\n{report.summary}\n")
    print(f"Deduplicated findings : {report.deduplicated_count}")
    print(f"Block the build?      : {'YES' if report.blocking_recommendation else 'no'}")
    if report.invariant_violations:
        print(f"Guardrail escalations : {len(report.invariant_violations)} "
              "(protected-severity suppression attempts blocked)")
    print("\nPrioritized findings:")
    for f in sorted(report.findings, key=lambda x: x.get("priority", 1_000)):
        flag = "  [HUMAN REVIEW]" if f.get("needs_human_review") else ""
        fp = "  (likely FP)" if f.get("likely_false_positive") else ""
        print(
            f"  #{f.get('priority', '?'):<3} "
            f"[{f.get('severity', '?').upper():<8}] "
            f"{f.get('rule_id', '')} — {f.get('title', '')}{fp}{flag}"
        )
        print(f"        scanners: {', '.join(f.get('scanners', []))}  @ {f.get('location', '')}")
        print(f"        action  : {f.get('recommended_action', '')}")
    print("\n" + "=" * 78 + "\n")


class AgentOrchestrator:
    """Coordinates agents behind the shared audit trail."""

    def __init__(self) -> None:
        self.audit = AuditLogger()
        self.triage = SecurityTriageAgent(audit=self.audit)

    def run_triage(self, sarif_paths: list[str]) -> TriageReport:
        self.audit.record("orchestrator", "run.triage", inputs=sarif_paths)
        return self.triage.triage(sarif_paths)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="DevSecOps agent orchestrator (Claude API).")
    parser.add_argument("paths", nargs="+", help="SARIF files, globs, or directories")
    parser.add_argument(
        "--fail-on-block",
        action="store_true",
        help="Exit 1 when the triage agent recommends blocking the build (for CI gates).",
    )
    args = parser.parse_args(argv)

    sarif_paths = _resolve_sarif(args.paths)
    if not sarif_paths:
        print("No SARIF files found in the given paths.", file=sys.stderr)
        return 2

    try:
        report = AgentOrchestrator().run_triage(sarif_paths)
    except AgentError as exc:
        print(f"Agent error: {exc}", file=sys.stderr)
        return 3

    _print_report(report)

    if args.fail_on_block and report.blocking_recommendation:
        print("Triage recommends BLOCKING the build.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
