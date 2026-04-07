"""Cocina Agent Library - Shared utilities for RabbitMQ-enabled Claude agents."""

__version__ = "1.0.0"
__author__ = "Cocina"

from .agent_base import CocinaAgentBase
from .rabbit_client import RabbitClient
from .message_builder import MessageBuilder

__all__ = [
    "CocinaAgentBase",
    "RabbitClient",
    "MessageBuilder",
]
