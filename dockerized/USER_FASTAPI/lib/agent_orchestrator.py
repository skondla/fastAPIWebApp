#!/usr/bin/env python3
# Author: skondla@me.com
# Purpose: Multi-step agent orchestrator for the DB restore workflow.
#          Uses Claude tool-use to plan and sequence the existing atomic
#          RDS operations (restore -> status check -> optional attach ->
#          notify) that previously required three separate manual form
#          submissions.
# -*- coding: utf-8 -*-

import os
import time
from dataclasses import dataclass, field
from typing import Callable, Optional

from anthropic import Anthropic
from botocore.exceptions import ClientError

import rds_ops

DEFAULT_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-5")
MAX_TOOL_STEPS = 8
MAX_WAIT_SECONDS_PER_CALL = 15
MAX_TOTAL_WAIT_SECONDS = 30

SYSTEM_PROMPT = """\
You are the workflow orchestrator for an RDS DB Restore Management Tool.
You have tools to restore a snapshot, check status, attach an instance to a
cluster, and send a team notification. Given the operator's request, plan and
execute the minimum necessary tool calls, in this order:

1. Always call restore_snapshot first.
2. Call check_db_status once immediately after the restore (wait_seconds=0).
   You may call it a second time with a short wait_seconds (<=15) if useful,
   but never more than twice total.
3. Only call attach_instance if the operator explicitly asked to attach an
   instance AND the endpoint is an Aurora cluster (contains "cluster"). Skip
   it otherwise and say why.
4. Call notify once after the restore, and once more after an attach if one
   was performed.

Do not call any tool more than twice. If a tool call fails, do not retry it
more than once, and explain the failure in your final summary instead of
attempting further destructive actions. When you are done, reply with a
short plain-text summary for the operator: what was done, the resulting
endpoint(s), and the final observed status.
"""

TOOLS = [
    {
        "name": "restore_snapshot",
        "description": (
            "Restore an RDS DB instance or cluster from a snapshot. Looks up "
            "subnet/security-group/engine info from the source endpoint and "
            "kicks off the restore. Returns the new endpoint identifier."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "snapshot_name": {
                    "type": "string",
                    "description": "RDS snapshot identifier to restore from.",
                },
                "source_endpoint": {
                    "type": "string",
                    "description": (
                        "Original DB/cluster endpoint the snapshot was taken "
                        "from. Endpoints containing 'cluster' are treated as "
                        "Aurora clusters."
                    ),
                },
            },
            "required": ["snapshot_name", "source_endpoint"],
        },
    },
    {
        "name": "check_db_status",
        "description": (
            "Check the current status of a restored DB instance or cluster. "
            "Optionally wait a few seconds first to let AWS state settle."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "source_endpoint": {
                    "type": "string",
                    "description": "Original endpoint (used only to detect cluster vs instance).",
                },
                "new_endpoint": {
                    "type": "string",
                    "description": "Identifier of the restored DB instance/cluster to check.",
                },
                "wait_seconds": {
                    "type": "integer",
                    "description": "Seconds to wait before checking (0-15).",
                    "default": 0,
                },
            },
            "required": ["source_endpoint", "new_endpoint"],
        },
    },
    {
        "name": "attach_instance",
        "description": (
            "Attach a new reader instance to an existing Aurora cluster. "
            "Only valid when the endpoint is a cluster."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "cluster_endpoint": {"type": "string"},
                "instance_class": {
                    "type": "string",
                    "description": "e.g. db.r5.large",
                },
            },
            "required": ["cluster_endpoint", "instance_class"],
        },
    },
    {
        "name": "notify",
        "description": (
            "Send a Slack message and email notifying the team of a workflow "
            "state change. Call once after restore, and once more after an "
            "attach if one was performed."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "identifier": {"type": "string", "description": "Snapshot or instance name."},
                "endpoint": {"type": "string", "description": "New/target endpoint."},
                "state": {"type": "string", "description": "Observed DB state, e.g. 'creating'."},
                "action": {"type": "string", "description": "e.g. 'Restoring', 'Attaching'."},
            },
            "required": ["identifier", "endpoint", "state", "action"],
        },
    },
]


@dataclass
class OrchestrationStep:
    tool: str
    input: dict
    result: str
    ok: bool


@dataclass
class OrchestrationResult:
    final_message: str
    steps: list = field(default_factory=list)


class RestoreOrchestrator:
    """Plans and executes the restore -> status -> attach -> notify workflow."""

    def __init__(self, api_key: Optional[str] = None, model: str = DEFAULT_MODEL):
        api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise RuntimeError("ANTHROPIC_API_KEY is not configured.")
        self._client = Anthropic(api_key=api_key)
        self._model = model

    def _dispatch(self, name: str, tool_input: dict, wait_budget: dict) -> str:
        if name == "restore_snapshot":
            snapshot_name = tool_input["snapshot_name"].strip()
            source_endpoint = tool_input["source_endpoint"].strip()
            new_endpoint = snapshot_name + "." + source_endpoint.split(".", 1)[1]
            rds_ops.db_restore(snapshot_name, source_endpoint)
            return f"Restore initiated. New endpoint: {new_endpoint}"

        if name == "check_db_status":
            wait_seconds = min(
                int(tool_input.get("wait_seconds", 0) or 0), MAX_WAIT_SECONDS_PER_CALL
            )
            wait_seconds = min(wait_seconds, max(0, MAX_TOTAL_WAIT_SECONDS - wait_budget["used"]))
            if wait_seconds > 0:
                time.sleep(wait_seconds)
                wait_budget["used"] += wait_seconds
            state = rds_ops.db_status(tool_input["source_endpoint"], tool_input["new_endpoint"])
            return f"Status: {state}"

        if name == "attach_instance":
            cluster_endpoint = tool_input["cluster_endpoint"].strip()
            if "cluster" not in cluster_endpoint:
                return f"Error: {cluster_endpoint} is not a cluster; cannot attach."
            instance_name = rds_ops.db_attach(cluster_endpoint, tool_input["instance_class"].strip())
            new_endpoint = f"{instance_name}.{cluster_endpoint.split('.', 1)[1]}"
            return f"Attach initiated. Instance: {instance_name}, new endpoint: {new_endpoint}"

        if name == "notify":
            rds_ops.slack_post(
                tool_input["identifier"],
                tool_input["endpoint"],
                tool_input["state"],
                tool_input["action"],
                "dbAgentOrchestrator",
            )
            rds_ops.send_email(tool_input["identifier"], tool_input["endpoint"], tool_input["state"])
            return "Notification sent."

        return f"Error: unknown tool '{name}'"

    def run(
        self,
        goal: str,
        snapshot_name: str,
        source_endpoint: str,
        target_instance_class: Optional[str] = None,
        on_step: Optional[Callable[[str, str, str], None]] = None,
    ) -> OrchestrationResult:
        user_prompt = (
            f"Operator request: {goal}\n"
            f"snapshot_name: {snapshot_name}\n"
            f"source_endpoint: {source_endpoint}\n"
            f"target_instance_class: {target_instance_class or '(not requested)'}"
        )
        messages = [{"role": "user", "content": user_prompt}]
        steps: list[OrchestrationStep] = []
        wait_budget = {"used": 0}

        for _ in range(MAX_TOOL_STEPS):
            response = self._client.messages.create(
                model=self._model,
                max_tokens=1024,
                system=SYSTEM_PROMPT,
                tools=TOOLS,
                messages=messages,
            )
            messages.append({"role": "assistant", "content": response.content})

            if response.stop_reason != "tool_use":
                final_text = "".join(
                    block.text for block in response.content if block.type == "text"
                )
                return OrchestrationResult(final_message=final_text, steps=steps)

            tool_results = []
            for block in response.content:
                if block.type != "tool_use":
                    continue
                try:
                    result_text = self._dispatch(block.name, block.input, wait_budget)
                    ok = not result_text.startswith("Error:")
                except ClientError as exc:
                    result_text = f"Error: AWS call failed: {exc}"
                    ok = False
                steps.append(
                    OrchestrationStep(tool=block.name, input=block.input, result=result_text, ok=ok)
                )
                if on_step:
                    on_step(block.name, str(block.input), result_text)
                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result_text,
                        "is_error": not ok,
                    }
                )
            messages.append({"role": "user", "content": tool_results})

        return OrchestrationResult(
            final_message="Stopped after reaching the maximum number of workflow steps.",
            steps=steps,
        )
