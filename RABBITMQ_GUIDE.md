# RabbitMQ Integration Guide for Cocina

## Overview

This guide explains how to use RabbitMQ-based agent communication in Cocina for multi-step workflow coordination.

## Quick Start

### 1. Start the Stack

```bash
cd /tmp/cocina
docker-compose up -d

# Wait for RabbitMQ to be healthy (30 seconds)
docker-compose logs rabbitmq
```

### 2. Setup Rails

```bash
cd /tmp/cocina/web
bundle install
rails db:migrate
rails s
```

### 3. Create Your First Workflow

1. Open http://localhost:3000/workflows/new
2. Fill in workflow name and description
3. Add steps by clicking "Add Step"
4. Select agents for each step
5. Set dependencies between steps
6. Click "Create Workflow"

### 4. Monitor Communication

1. Start the workflow from the show page
2. Watch real-time progress updates
3. Click "View Messages" to see inter-agent communication logs

## Architecture

### Message Flow

```
Web UI (Rails)
    │
    ├─→ Create Workflow
    │   └─→ Store in SQLite
    │
    ├─→ Start Workflow
    │   └─→ DelegateTaskJob publishes to RabbitMQ
    │
    ├─→ Agent receives message
    │   ├─→ Acknowledges task
    │   ├─→ Processes with Claude
    │   └─→ Publishes completion to RabbitMQ
    │
    ├─→ ProcessAgentMessagesJob consumes
    │   └─→ Updates WorkflowStep status
    │
    └─→ ActionCable broadcasts
        └─→ Web UI updates in real-time
```

### Component Breakdown

| Component | Role |
|-----------|------|
| **Rails App** | Orchestrates workflows, manages state, broadcasts updates |
| **RabbitMQ** | Message bus for agent communication |
| **Chef Agent** | Plans multi-step tasks |
| **Sous Agents** | Execute individual steps |
| **SQLite** | Persists workflows, steps, messages |

## Agent Modes

### Environment Variable Mode (Legacy)

Agents process a single task from the TASK env var and exit.

```bash
docker run -e AGENT_ID=chef_001 -e TASK="Cook dinner" agent_image
```

### RabbitMQ Mode (Pure)

Agents connect to RabbitMQ and run indefinitely, consuming tasks from a queue.

```bash
docker run \
  -e AGENT_ID=chef_001 \
  -e RABBITMQ_HOST=rabbitmq \
  -e RABBITMQ_QUEUE=chef_tasks \
  -e MODE=rabbitmq \
  agent_image
```

### Hybrid Mode (Recommended)

Agents try RabbitMQ first; fallback to env var if unavailable.

```bash
docker run \
  -e AGENT_ID=chef_001 \
  -e TASK="Cook dinner (fallback)" \
  -e RABBITMQ_HOST=rabbitmq \
  -e MODE=hybrid \
  agent_image
```

## Message Protocol

All messages follow this structure:

```json
{
  "message_type": "task.delegated|task.acknowledgment|task.completion|...",
  "message_id": "uuid",
  "correlation_id": "uuid",
  "workflow_id": "uuid",
  "agent_id": "sender_name",
  "timestamp": "ISO8601",
  "payload": {
    "task_id": "workflow:step_id",
    "..."
  }
}
```

### Message Types

**task.delegated** - Rails → Agent (initiate task)
```json
{
  "payload": {
    "task_id": "string",
    "task_description": "what to do",
    "dependencies": ["other_task_ids"],
    "priority": "normal|high",
    "timeout_seconds": 3600
  }
}
```

**task.acknowledgment** - Agent → Rails (started)
```json
{
  "payload": {
    "task_id": "string",
    "status": "processing",
    "started_at": "ISO8601"
  }
}
```

**task.completion** - Agent → Rails (finished)
```json
{
  "payload": {
    "task_id": "string",
    "status": "completed",
    "result": "output from Claude",
    "tokens_used": {"input": 123, "output": 456},
    "completed_at": "ISO8601"
  }
}
```

**error.notification** - Agent → Rails (failed)
```json
{
  "payload": {
    "task_id": "string",
    "error_type": "ProcessingError",
    "error_message": "details",
    "stacktrace": null
  }
}
```

## Configuration

### Environment Variables

```bash
# RabbitMQ connection (in Rails)
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USER=cocina
RABBITMQ_PASS=cocina_pass

# Agent configuration (in agents)
AGENT_ID=chef_001
TASK="Default task"
ANTHROPIC_API_KEY=sk-ant-...
MODE=hybrid
RABBITMQ_QUEUE=chef_tasks
```

### Docker Compose Override

For local development:

```yaml
# docker-compose.override.yml
services:
  rabbitmq:
    ports:
      - "15672:15672"  # Management UI

  chef_agent:
    environment:
      MODE: env  # Use env mode for testing
```

## Monitoring

### RabbitMQ Management UI

Access at http://localhost:15672
- Username: `cocina`
- Password: `cocina_pass`

View:
- Queue sizes and message counts
- Connection details
- Dead letter queues

### Rails Logs

```bash
cd web
tail -f log/development.log | grep "RabbitMQ\|workflow\|message"
```

### Agent Logs

```bash
docker logs chef_agent -f
docker logs sous_agent_1 -f
```

## Database Schema

### Workflows Table

```
id, workflow_id, name, description, status,
initiated_by, total_steps, completed_steps,
created_at, started_at, completed_at, error_message
```

### Workflow Steps Table

```
id, workflow_id, step_id, task_id, agent_id,
description, status, depends_on_steps (JSON),
result (JSON), created_at, started_at, completed_at
```

### Agent Messages Table

```
id, message_id, correlation_id, workflow_id,
message_type, sender_agent_id, receiver_agent_id,
payload (JSON), status, processed_at, error_message
```

### Message Logs Table

```
id, agent_run_id, message_id, direction,
message_type, content (JSON), created_at
```

## Troubleshooting

### Agents not connecting to RabbitMQ

**Problem**: `ConnectionRefused` in agent logs

**Solution**:
1. Verify RabbitMQ container is running: `docker ps | grep rabbitmq`
2. Check health: `curl -u cocina:cocina_pass http://localhost:15672/api/aliveness-test/%2F`
3. Verify agent can reach host: `docker exec chef_agent ping rabbitmq`

### Messages not being processed

**Problem**: Messages stuck in "received" status in database

**Solution**:
1. Check `ProcessAgentMessagesJob` is running
2. Verify Rails can connect: `rails c` and run `Cocina::MessageBroker.instance.connected?`
3. Check Rails logs for errors

### Workflow stuck in pending

**Problem**: Workflow created but steps never start

**Solution**:
1. Verify agent exists: `Agent.find_by(name: "agent_name")`
2. Check agent is configured for RabbitMQ: `agent.supports_rabbitmq == true`
3. Manually trigger: `DelegateTaskJob.perform_now(workflow_id, step_id, agent_id, description)`

### Agent crashes after receiving task

**Problem**: Agent container exits unexpectedly

**Solution**:
1. Check agent logs: `docker logs agent_name`
2. Verify Claude API key is set
3. Test agent locally with env mode: `TASK="test" python agent.py`

## Advanced Usage

### Custom Workflow Logic

In `WorkflowsController`:

```ruby
def create
  @workflow = Workflow.create!(workflow_params)

  # Custom logic for different workflow types
  case @workflow.name
  when /cook/i
    setup_cooking_workflow(@workflow)
  when /build/i
    setup_build_workflow(@workflow)
  end
end
```

### Conditional Step Execution

In `ProcessAgentMessagesJob`:

```ruby
def check_and_delegate_next_steps(workflow)
  workflow.workflow_steps.where(status: "pending").each do |step|
    # Custom condition logic
    next unless condition_met?(step)

    DelegateTaskJob.perform_later(...)
  end
end
```

### Custom Message Handling

In agent code:

```python
def process_message(self, message):
  if message["message_type"] == "task.delegated":
    # Custom handling
    dependencies = message["payload"]["dependencies"]

    # Could implement parallel processing
    for dep in dependencies:
      self.wait_for_dependency(dep)
```

## Performance Tips

1. **Batch Operations**: Process multiple steps in parallel
2. **Message Prefetching**: Set `prefetch_count` in RabbitMQ client
3. **Database Indexing**: Ensure indexes on common queries
4. **Workflow Size**: Keep workflows < 100 steps for best performance

## Security Considerations

1. **RabbitMQ Credentials**: Use strong passwords in production
2. **API Keys**: Never commit `ANTHROPIC_API_KEY` to repository
3. **Message Validation**: Rails validates message format before processing
4. **Network Isolation**: Run RabbitMQ and agents in same Docker network

## Migration from Env Var to RabbitMQ

1. Add RabbitMQ service to docker-compose
2. Update agents to hybrid mode
3. Create workflows in Rails UI
4. Verify message flow in communication logs
5. Remove legacy TASK-based task execution

## Testing

Run integration tests:

```bash
cd /tmp/cocina/web
bundle exec rspec spec/integration/workflow_integration_spec.rb
```

Test message publishing:

```ruby
# In Rails console
workflow = Workflow.create!(workflow_id: SecureRandom.uuid)
step = workflow.workflow_steps.create!(...)
DelegateTaskJob.perform_now(workflow.workflow_id, step.step_id, agent, "test")
```

## Further Reading

- [Message Queue Patterns](https://www.rabbitmq.com/documentation.html)
- [Claude API Documentation](https://docs.anthropic.com)
- [Rails ActiveJob](https://guides.rubyonrails.org/active_job_basics.html)
- [ActionCable](https://guides.rubyonrails.org/action_cable_overview.html)
