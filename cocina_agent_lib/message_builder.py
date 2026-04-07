"""Message builder for Cocina agents."""

import uuid
from datetime import datetime


class MessageBuilder:
    """Helper class to construct properly-formatted messages."""

    @staticmethod
    def task_delegated(task_id, task_description, agent_id="system", correlation_id=None, workflow_id=None, dependencies=None):
        """Build a task.delegated message."""
        return {
            "message_type": "task.delegated",
            "message_id": str(uuid.uuid4()),
            "correlation_id": correlation_id or str(uuid.uuid4()),
            "workflow_id": workflow_id,
            "agent_id": agent_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "payload": {
                "task_id": task_id,
                "task_description": task_description,
                "dependencies": dependencies or [],
                "priority": "normal",
                "timeout_seconds": 3600,
            },
        }

    @staticmethod
    def task_acknowledgment(task_id, correlation_id, workflow_id, agent_id, status="processing"):
        """Build a task.acknowledgment message."""
        return {
            "message_type": "task.acknowledgment",
            "message_id": str(uuid.uuid4()),
            "correlation_id": correlation_id,
            "workflow_id": workflow_id,
            "agent_id": agent_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "payload": {
                "task_id": task_id,
                "status": status,
                "started_at": datetime.utcnow().isoformat() + "Z",
            },
        }

    @staticmethod
    def task_progress(task_id, correlation_id, workflow_id, agent_id, progress_percent, status_message=""):
        """Build a task.progress message."""
        return {
            "message_type": "task.progress",
            "message_id": str(uuid.uuid4()),
            "correlation_id": correlation_id,
            "workflow_id": workflow_id,
            "agent_id": agent_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "payload": {
                "task_id": task_id,
                "progress_percent": progress_percent,
                "status_message": status_message,
            },
        }

    @staticmethod
    def task_completion(task_id, correlation_id, workflow_id, agent_id, status="completed", result="", tokens_used=None):
        """Build a task.completion message."""
        return {
            "message_type": "task.completion",
            "message_id": str(uuid.uuid4()),
            "correlation_id": correlation_id,
            "workflow_id": workflow_id,
            "agent_id": agent_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "payload": {
                "task_id": task_id,
                "status": status,
                "result": result,
                "tokens_used": tokens_used or {"input": 0, "output": 0},
                "completed_at": datetime.utcnow().isoformat() + "Z",
            },
        }

    @staticmethod
    def task_error(task_id, correlation_id, workflow_id, agent_id, error_type, error_message, stacktrace=None):
        """Build an error.notification message."""
        return {
            "message_type": "error.notification",
            "message_id": str(uuid.uuid4()),
            "correlation_id": correlation_id,
            "workflow_id": workflow_id,
            "agent_id": agent_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "payload": {
                "task_id": task_id,
                "error_type": error_type,
                "error_message": error_message,
                "stacktrace": stacktrace,
            },
        }

    @staticmethod
    def agent_heartbeat(agent_id, status="ready", current_task_id=None, uptime_seconds=0):
        """Build an agent.heartbeat message."""
        return {
            "message_type": "agent.heartbeat",
            "message_id": str(uuid.uuid4()),
            "correlation_id": str(uuid.uuid4()),
            "workflow_id": None,
            "agent_id": agent_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "payload": {
                "status": status,
                "current_task_id": current_task_id,
                "uptime_seconds": uptime_seconds,
            },
        }

    @staticmethod
    def agent_log(agent_id, level, message, context=None, correlation_id=None, workflow_id=None):
        """Build an agent.log_event message."""
        return {
            "message_type": "agent.log_event",
            "message_id": str(uuid.uuid4()),
            "correlation_id": correlation_id or str(uuid.uuid4()),
            "workflow_id": workflow_id,
            "agent_id": agent_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "payload": {
                "level": level,
                "message": message,
                "context": context or {},
            },
        }
