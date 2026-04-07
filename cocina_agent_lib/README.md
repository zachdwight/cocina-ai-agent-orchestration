# Cocina Agent Library

Python library for building Claude-powered agents with RabbitMQ support.

## Features

- **Hybrid Mode**: Works with or without RabbitMQ
- **Message-Driven**: Long-running agents consuming tasks from queues
- **Claude Integration**: Built-in Anthropic API client
- **Structured Logging**: Comprehensive logging for debugging
- **Error Handling**: Automatic error notifications and recovery

## Installation

```bash
pip install -r requirements.txt
```

## Basic Usage

### Create Your Agent

```python
from anthropic import Anthropic
from cocina_agent_lib import CocinaAgentBase

class MyAgent(CocinaAgentBase):
    def __init__(self):
        super().__init__()
        self.anthropic_client = Anthropic(api_key=self.api_key)

    def call_claude(self, task_description):
        """Call Claude with your task."""
        message = self.anthropic_client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=2048,
            system="You are a helpful AI assistant.",
            messages=[{"role": "user", "content": task_description}]
        )
        return message.content[0].text

    def process_message(self, message):
        """Handle incoming RabbitMQ messages."""
        msg_type = message.get("message_type")

        if msg_type == "task.delegated":
            payload = message.get("payload", {})
            task_id = payload.get("task_id")
            task_desc = payload.get("task_description")

            # Acknowledge receipt
            self.acknowledge_task(
                task_id,
                message.get("correlation_id"),
                message.get("workflow_id")
            )

            # Process task
            result = self.call_claude(task_desc)

            # Report completion
            self.complete_task(
                task_id,
                message.get("correlation_id"),
                message.get("workflow_id"),
                result
            )

if __name__ == "__main__":
    agent = MyAgent()
    import sys
    sys.exit(agent.run())
```

### Run Modes

**Environment Variable Mode**:
```bash
export TASK="What is 2+2?"
python my_agent.py
```

**RabbitMQ Mode**:
```bash
export RABBITMQ_HOST=localhost
export RABBITMQ_QUEUE=my_tasks
python my_agent.py
```

**Hybrid Mode** (default):
```bash
export TASK="Fallback task"
export RABBITMQ_HOST=localhost
python my_agent.py
```

## API Reference

### CocinaAgentBase

Base class for all Cocina agents.

#### Properties

- `agent_id`: Unique agent identifier
- `mode`: Execution mode (env, rabbitmq, hybrid)
- `task`: Task from TASK env var
- `api_key`: ANTHROPIC_API_KEY
- `current_task_id`: Currently executing task ID

#### Methods

**`run()`**
Main entry point. Auto-detects mode and runs accordingly.

**`call_claude(task_description)`**
Abstract method. Implement to call Claude API.

**`process_message(message)`**
Abstract method. Implement to handle RabbitMQ messages.

**`acknowledge_task(task_id, correlation_id, workflow_id)`**
Send task acknowledgment.

**`complete_task(task_id, correlation_id, workflow_id, result, tokens_used=None)`**
Send task completion with result.

**`report_error(task_id, correlation_id, workflow_id, error_type, error_message, stacktrace=None)`**
Send error notification.

**`send_heartbeat(status="ready", current_task_id=None)`**
Send agent health status.

**`log_event(level, message, context=None, correlation_id=None, workflow_id=None)`**
Log structured event.

### RabbitClient

Low-level RabbitMQ client wrapper.

```python
from cocina_agent_lib import RabbitClient

client = RabbitClient(
    host="localhost",
    port=5672,
    username="cocina",
    password="cocina_pass"
)

if client.connect():
    # Declare queue
    client.declare_queue("my_tasks")

    # Publish message
    client.publish(
        {"message_type": "test"},
        routing_key="my_tasks"
    )

    # Consume messages
    def callback(message, method):
        print(f"Received: {message}")

    client.consume("my_tasks", callback)
```

### MessageBuilder

Helper for constructing properly formatted messages.

```python
from cocina_agent_lib import MessageBuilder

# Task delegation
msg = MessageBuilder.task_delegated(
    task_id="task_123",
    task_description="Cook dinner",
    correlation_id="corr_123",
    workflow_id="wf_123"
)

# Task completion
msg = MessageBuilder.task_completion(
    task_id="task_123",
    correlation_id="corr_123",
    workflow_id="wf_123",
    agent_id="chef_001",
    result="Menu planned",
    tokens_used={"input": 100, "output": 50}
)

# Error notification
msg = MessageBuilder.task_error(
    task_id="task_123",
    correlation_id="corr_123",
    workflow_id="wf_123",
    agent_id="chef_001",
    error_type="APIError",
    error_message="Claude API timeout"
)
```

## Environment Variables

### Required

- `ANTHROPIC_API_KEY`: Your Claude API key

### Optional

- `AGENT_ID`: Unique agent identifier (default: "unknown")
- `MODE`: Execution mode - "env", "rabbitmq", or "hybrid" (default: "hybrid")
- `TASK`: Task to process (used in env mode or as fallback)

### RabbitMQ

- `RABBITMQ_HOST`: Host (default: "localhost")
- `RABBITMQ_PORT`: Port (default: "5672")
- `RABBITMQ_USER`: Username (default: "guest")
- `RABBITMQ_PASS`: Password (default: "guest")
- `RABBITMQ_QUEUE`: Queue name (default: "{AGENT_ID}_tasks")

## Logging

All agents automatically log to stdout with timestamps:

```
[2026-04-07 10:23:45,123] [my_agent] [INFO] Starting agent...
[2026-04-07 10:23:46,456] [my_agent] [INFO] Connected to RabbitMQ
[2026-04-07 10:23:47,789] [my_agent] [INFO] Received message: task.delegated
```

Control log level with `logging`:

```python
import logging

logging.basicConfig(level=logging.DEBUG)
```

## Error Handling

Agents automatically handle errors:

1. **RabbitMQ Connection Failure** → Fallback to env var mode (hybrid)
2. **Message Processing Error** → Send error notification to Rails
3. **Claude API Failure** → Retry with exponential backoff (client-side)

## Testing

Test your agent locally:

```bash
# Test env mode
export TASK="What is AI?"
python my_agent.py

# Test with mock RabbitMQ
export RABBITMQ_HOST=localhost
export MODE=rabbitmq
python my_agent.py
```

## Docker

Example Dockerfile:

```dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY cocina_agent_lib/ /app/cocina_agent_lib/
COPY my_agent.py .

CMD ["python", "my_agent.py"]
```

Build and run:

```bash
docker build -t my_agent .
docker run -e ANTHROPIC_API_KEY=sk-ant-... my_agent
```

## Advanced

### Custom Message Handling

```python
def process_message(self, message):
    msg_type = message.get("message_type")

    if msg_type == "task.delegated":
        # Handle delegation
        self.handle_delegation(message)
    elif msg_type == "workflow.coordination":
        # Handle coordination
        self.handle_coordination(message)
    else:
        logger.warning(f"Unknown message type: {msg_type}")
```

### Message Correlation

Track related messages using correlation_id:

```python
def process_message(self, message):
    corr_id = message.get("correlation_id")
    wf_id = message.get("workflow_id")

    # All responses should include these
    self.log_event(
        "info",
        f"Processing message for workflow {wf_id}",
        correlation_id=corr_id,
        workflow_id=wf_id
    )
```

### Graceful Shutdown

```python
import signal
import sys

def shutdown_handler(sig, frame):
    logger.info("Shutting down...")
    if agent.rabbit_client:
        agent.rabbit_client.close()
    sys.exit(0)

signal.signal(signal.SIGTERM, shutdown_handler)
signal.signal(signal.SIGINT, shutdown_handler)
```

## Troubleshooting

**Agent exits immediately in RabbitMQ mode**
- Verify `RABBITMQ_HOST` is set
- Check RabbitMQ is running: `docker ps | grep rabbitmq`
- Test connection: `python -c "from pika import BlockingConnection; BlockingConnection(...).close()"`

**Messages not being received**
- Verify queue name matches in Rails and agent
- Check RabbitMQ Management UI for queue existence
- Ensure message format matches protocol

**High CPU usage**
- Add sleep/backoff when no messages: `time.sleep(1)`
- Reduce prefetch count for slower processing
- Check for message processing loops

## Contributing

Found a bug or want to improve? Submit a pull request!

## License

MIT - See LICENSE file
