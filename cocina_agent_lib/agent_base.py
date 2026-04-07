"""Base class for Cocina agents with RabbitMQ and hybrid mode support."""

import os
import sys
import json
import logging
import time
from abc import ABC, abstractmethod

from .rabbit_client import RabbitClient
from .message_builder import MessageBuilder

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


class CocinaAgentBase(ABC):
    """Base class for RabbitMQ-enabled Cocina agents.

    Supports three modes:
    - env: Legacy mode - read TASK from environment variable
    - rabbitmq: Pure RabbitMQ mode - listen for messages indefinitely
    - hybrid: Try RabbitMQ first, fallback to env var (default)
    """

    def __init__(self):
        """Initialize agent from environment variables."""
        self.agent_id = os.environ.get("AGENT_ID", "unknown")
        self.mode = os.environ.get("MODE", "hybrid").lower()
        self.task = os.environ.get("TASK", "")
        self.api_key = os.environ.get("ANTHROPIC_API_KEY", "")

        # RabbitMQ configuration
        self.rabbitmq_host = os.environ.get("RABBITMQ_HOST", "localhost")
        self.rabbitmq_port = int(os.environ.get("RABBITMQ_PORT", "5672"))
        self.rabbitmq_user = os.environ.get("RABBITMQ_USER", "guest")
        self.rabbitmq_pass = os.environ.get("RABBITMQ_PASS", "guest")
        self.rabbitmq_queue = os.environ.get("RABBITMQ_QUEUE", f"{self.agent_id}_tasks")

        self.rabbit_client = None
        self.current_task_id = None
        self.start_time = time.time()

        logger.info(f"Initialized agent: {self.agent_id} (mode: {self.mode})")

    def connect_rabbitmq(self):
        """Connect to RabbitMQ."""
        try:
            self.rabbit_client = RabbitClient(
                host=self.rabbitmq_host,
                port=self.rabbitmq_port,
                username=self.rabbitmq_user,
                password=self.rabbitmq_pass,
            )
            if self.rabbit_client.connect():
                logger.info(f"Connected to RabbitMQ at {self.rabbitmq_host}:{self.rabbitmq_port}")

                # Declare queue
                self.rabbit_client.declare_queue(self.rabbitmq_queue, durable=True)
                logger.info(f"Declared queue: {self.rabbitmq_queue}")
                return True
            else:
                logger.warning("Failed to connect to RabbitMQ")
                return False
        except Exception as e:
            logger.error(f"Error connecting to RabbitMQ: {str(e)}")
            return False

    def start_message_loop(self):
        """Start consuming messages from RabbitMQ queue."""
        if not self.rabbit_client or not self.rabbit_client.connected:
            logger.error("Not connected to RabbitMQ")
            return False

        logger.info(f"Starting message loop for queue: {self.rabbitmq_queue}")

        def message_callback(message, method):
            try:
                logger.info(f"Received message: {message.get('message_type')}")
                self.process_message(message)
            except Exception as e:
                logger.error(f"Error processing message: {str(e)}")

        try:
            self.rabbit_client.consume(self.rabbitmq_queue, message_callback)
        except KeyboardInterrupt:
            logger.info("Shutting down agent")
            return True
        except Exception as e:
            logger.error(f"Error in message loop: {str(e)}")
            return False

    @abstractmethod
    def process_message(self, message):
        """Process a received message. Override in subclass.

        Args:
            message: Parsed JSON message dict with structure:
                {
                    "message_type": "task.delegated",
                    "message_id": "uuid",
                    "correlation_id": "uuid",
                    "workflow_id": "uuid",
                    "agent_id": "sender_id",
                    "payload": {...}
                }
        """
        pass

    def process_task(self, task_description, task_id=None, correlation_id=None, workflow_id=None):
        """Process a task synchronously (called from process_message).

        This is an internal helper. Override process_message for custom handling.

        Args:
            task_description: The task to process
            task_id: Unique task identifier
            correlation_id: For tracing
            workflow_id: Associated workflow

        Returns:
            Result string
        """
        self.current_task_id = task_id
        return self.call_claude(task_description)

    def send_message(self, message_type, payload, correlation_id=None, workflow_id=None):
        """Send a message via RabbitMQ.

        Args:
            message_type: Type of message (e.g., 'task.completion')
            payload: Message payload dict
            correlation_id: For tracing (auto-generated if not provided)
            workflow_id: Associated workflow

        Returns:
            True if successful, False otherwise
        """
        if not self.rabbit_client or not self.rabbit_client.connected:
            logger.warning("Not connected to RabbitMQ, skipping message send")
            return False

        try:
            message = {
                "message_type": message_type,
                "message_id": str(payload.get("message_id", "")),
                "correlation_id": correlation_id,
                "workflow_id": workflow_id,
                "agent_id": self.agent_id,
                "timestamp": payload.get("timestamp", ""),
                "payload": {k: v for k, v in payload.items() if k not in ["message_id", "timestamp"]},
            }
            return self.rabbit_client.publish(message, routing_key="system_messages", exchange="")
        except Exception as e:
            logger.error(f"Error sending message: {str(e)}")
            return False

    def acknowledge_task(self, task_id, correlation_id, workflow_id):
        """Send task acknowledgment."""
        msg = MessageBuilder.task_acknowledgment(
            task_id=task_id,
            correlation_id=correlation_id,
            workflow_id=workflow_id,
            agent_id=self.agent_id,
        )
        return self.rabbit_client.publish(msg, routing_key="system_messages", exchange="")

    def complete_task(self, task_id, correlation_id, workflow_id, result, tokens_used=None):
        """Send task completion message."""
        msg = MessageBuilder.task_completion(
            task_id=task_id,
            correlation_id=correlation_id,
            workflow_id=workflow_id,
            agent_id=self.agent_id,
            status="completed",
            result=result,
            tokens_used=tokens_used,
        )
        return self.rabbit_client.publish(msg, routing_key="system_messages", exchange="")

    def report_error(self, task_id, correlation_id, workflow_id, error_type, error_message, stacktrace=None):
        """Send error notification."""
        msg = MessageBuilder.task_error(
            task_id=task_id,
            correlation_id=correlation_id,
            workflow_id=workflow_id,
            agent_id=self.agent_id,
            error_type=error_type,
            error_message=error_message,
            stacktrace=stacktrace,
        )
        return self.rabbit_client.publish(msg, routing_key="system_messages", exchange="")

    def send_heartbeat(self, status="ready", current_task_id=None):
        """Send a heartbeat message."""
        uptime = int(time.time() - self.start_time)
        msg = MessageBuilder.agent_heartbeat(
            agent_id=self.agent_id,
            status=status,
            current_task_id=current_task_id or self.current_task_id,
            uptime_seconds=uptime,
        )
        return self.rabbit_client.publish(msg, routing_key="system_messages", exchange="")

    def log_event(self, level, message, context=None, correlation_id=None, workflow_id=None):
        """Log a structured event."""
        msg = MessageBuilder.agent_log(
            agent_id=self.agent_id,
            level=level,
            message=message,
            context=context,
            correlation_id=correlation_id,
            workflow_id=workflow_id,
        )
        return self.rabbit_client.publish(msg, routing_key="system_messages", exchange="")

    def call_claude(self, task_description):
        """Call Claude API. Override in subclass."""
        raise NotImplementedError("Subclasses must implement call_claude()")

    def run(self):
        """Main entry point. Determines mode and runs accordingly."""
        logger.info(f"Starting Cocina agent in {self.mode} mode")

        if self.mode == "env":
            # Legacy environment variable mode
            return self._run_env_mode()
        elif self.mode == "rabbitmq":
            # Pure RabbitMQ mode
            return self._run_rabbitmq_mode()
        elif self.mode == "hybrid":
            # Try RabbitMQ first, fallback to env
            return self._run_hybrid_mode()
        else:
            logger.error(f"Unknown mode: {self.mode}")
            sys.exit(1)

    def _run_env_mode(self):
        """Run in environment variable mode (legacy)."""
        if not self.task:
            logger.error("No TASK environment variable provided")
            sys.exit(1)

        logger.info(f"Processing task (env mode): {self.task[:100]}...")
        try:
            result = self.call_claude(self.task)
            logger.info("Task completed successfully")
            print(result)
            return 0
        except Exception as e:
            logger.error(f"Error processing task: {str(e)}")
            sys.exit(1)

    def _run_rabbitmq_mode(self):
        """Run in pure RabbitMQ mode."""
        if not self.connect_rabbitmq():
            logger.error("Failed to connect to RabbitMQ")
            sys.exit(1)

        logger.info("Running in pure RabbitMQ mode")
        try:
            self.start_message_loop()
            return 0
        except Exception as e:
            logger.error(f"Error in RabbitMQ mode: {str(e)}")
            return 1
        finally:
            if self.rabbit_client:
                self.rabbit_client.close()

    def _run_hybrid_mode(self):
        """Run in hybrid mode - try RabbitMQ, fallback to env."""
        logger.info("Running in hybrid mode (RabbitMQ preferred)")

        # Try to connect to RabbitMQ
        if self.connect_rabbitmq():
            logger.info("Connected to RabbitMQ, starting message loop")
            try:
                self.start_message_loop()
                return 0
            except Exception as e:
                logger.error(f"Error in message loop: {str(e)}")
                return 1
            finally:
                if self.rabbit_client:
                    self.rabbit_client.close()
        else:
            # Fallback to environment variable mode
            logger.warning("Could not connect to RabbitMQ, falling back to env var mode")
            if not self.task:
                logger.error("No TASK environment variable provided for fallback")
                sys.exit(1)

            logger.info(f"Processing task (env fallback): {self.task[:100]}...")
            try:
                result = self.call_claude(self.task)
                logger.info("Task completed successfully")
                print(result)
                return 0
            except Exception as e:
                logger.error(f"Error processing task: {str(e)}")
                sys.exit(1)

    def __del__(self):
        """Cleanup on agent shutdown."""
        if self.rabbit_client:
            self.rabbit_client.close()
