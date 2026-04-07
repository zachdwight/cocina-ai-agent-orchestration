"""Sous Chef Agent - Executes specific culinary sub-tasks using Claude."""

import os
import sys
import logging
from anthropic import Anthropic
from cocina_agent_lib import CocinaAgentBase, MessageBuilder

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


class SousChefAgent(CocinaAgentBase):
    """Sous Chef agent that executes specific sub-tasks."""

    def __init__(self):
        super().__init__()
        self.anthropic_client = Anthropic(api_key=self.api_key)

    def process_message(self, message):
        """Handle incoming messages."""
        message_type = message.get("message_type")
        payload = message.get("payload", {})
        correlation_id = message.get("correlation_id")
        workflow_id = message.get("workflow_id")

        logger.info(f"Sous Chef processing message type: {message_type}")

        if message_type == "task.delegated":
            self._handle_delegated_task(message, correlation_id, workflow_id)
        elif message_type == "agent.heartbeat":
            logger.debug("Received heartbeat")
        else:
            logger.warning(f"Unknown message type: {message_type}")

    def _handle_delegated_task(self, message, correlation_id, workflow_id):
        """Handle a delegated task."""
        payload = message.get("payload", {})
        task_id = payload.get("task_id")
        task_description = payload.get("task_description", "")

        logger.info(f"Sous Chef received task: {task_id}")
        print(f"[Sous Chef Agent | ID: {self.agent_id}] Starting task: {task_id}...")

        try:
            # Send acknowledgment
            self.acknowledge_task(task_id, correlation_id, workflow_id)
            logger.info(f"Acknowledged task {task_id}")

            # Process the task
            logger.info(f"Calling Claude for task: {task_description[:100]}...")
            result = self.call_claude(task_description)

            # Send completion
            self.complete_task(
                task_id=task_id,
                correlation_id=correlation_id,
                workflow_id=workflow_id,
                result=result,
            )
            logger.info(f"Completed task {task_id}")
            print(f"[Sous Chef Agent | ID: {self.agent_id}] Task {task_id} completed.")

        except Exception as e:
            logger.error(f"Error processing task: {str(e)}")
            self.report_error(
                task_id=task_id,
                correlation_id=correlation_id,
                workflow_id=workflow_id,
                error_type="ProcessingError",
                error_message=str(e),
            )

    def call_claude(self, task_description):
        """Call Claude API to process task."""
        if not self.api_key:
            raise ValueError("ANTHROPIC_API_KEY not set")

        logger.info("Calling Claude API...")
        print("[Sous Chef Agent] Calling Claude API...")

        message = self.anthropic_client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=2048,
            system=(
                "You are the Sous Chef AI agent. Your role is to execute specific culinary sub-tasks "
                "with precision and detail. When given a task, respond with thorough, step-by-step "
                "instructions including ingredients, quantities, timing, and technique. Be practical "
                "and exact."
            ),
            messages=[{"role": "user", "content": task_description}],
        )

        result = message.content[0].text
        print(f"[Sous Chef Agent | ID: {self.agent_id}] Result:\n{result}")
        print(f"[Sous Chef Agent | ID: {self.agent_id}] Done. (Input tokens: {message.usage.input_tokens}, Output tokens: {message.usage.output_tokens})")

        return result


if __name__ == "__main__":
    agent = SousChefAgent()
    sys.exit(agent.run())
