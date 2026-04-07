# 🍳 `cocina` — AI Agent Orchestrator

> *cocina* (Spanish) — _kitchen_. Because great AI agents, like great meals, need a well-run kitchen.

`cocina` orchestrates the lifecycle of multiple Claude-powered AI agents running in Docker containers. Use it from the **CLI** for quick control, or spin up the **Rails web UI** to manage, monitor, and stream logs from your browser.

---

## How It Works

```
┌──────────────────────────────────────────────────────┐
│               cocina (CLI or Web UI)                 │
│                   the expeditor                      │
└───────────┬──────────────────────┬───────────────────┘
            │                      │
    ┌───────▼──────┐       ┌───────▼──────┐
    │  chef_agent  │       │  sous_agent  │
    │  Docker ctr  │  ...  │  Docker ctr  │
    │  Claude API  │       │  Claude API  │
    └──────────────┘       └──────────────┘
```

The **Head Chef** agent plans and coordinates. The **Sous Chef** executes specific sub-tasks. Both call the Claude API and report results to stdout. Add as many agents as your kitchen needs.

---

## Features

### Core Agent Orchestration
| Feature | Description |
|---|---|
| **Claude API** | Agents call `claude-haiku-4-5-20251001` by default — fast and cost-efficient |
| **Task-driven** | Pass any task to an agent via the `TASK` env var or RabbitMQ queue |
| **Web UI** | Rails 8 dashboard — start/stop agents, stream live logs, view run history, manage workflows |
| **Live log streaming** | ActionCable WebSocket streams `docker logs --follow` to your browser |
| **Turbo status updates** | Agent status badges update in-place without page refreshes |
| **JSON config** | Define agents inline or in an external `agents_config.json` |
| **Full lifecycle** | Build, start, stop, restart, monitor, logs, cleanup — CLI or UI |
| **Health checks** | Waits for Docker `HEALTHCHECK` before declaring an agent ready |
| **Resource stats** | Real-time CPU/memory via `docker stats` |
| **Compose-aware** | Automatically uses `docker compose` if a compose file is detected |

### 🆕 RabbitMQ Workflow Orchestration
| Feature | Description |
|---|---|
| **Multi-step workflows** | Create workflows with dependent steps, automatic dependency resolution |
| **Inter-agent communication** | Async message queuing via RabbitMQ for coordinated task execution |
| **Real-time progress** | Live workflow progress tracking with WebSocket updates (ActionCable) |
| **Message logging** | Full audit trail of all inter-agent messages persisted to database |
| **Workflow builder** | Create multi-step workflows with visual builder in web UI |
| **Step dependencies** | Define which steps depend on others, auto-execute when ready |
| **Agent coordination** | Multiple agents can work together on same workflow asynchronously |
| **Error handling** | Automatic error notifications and task recovery mechanisms |
| **Hybrid agent mode** | Agents work with RabbitMQ OR fallback to env vars (no RabbitMQ required) |

---

## Prerequisites

- **Ruby** 3.1+ (web UI) / 2.7+ (CLI only)
- **Docker** Engine running
- **Anthropic API key** — [get one here](https://console.anthropic.com/)

---

## Project Structure

```
.
├── cocina.rb                     # CLI orchestrator — works standalone
├── docker-compose.yml            # 🆕 Full stack: RabbitMQ, agents, persistence
├── cocina_agent_lib/             # 🆕 Shared Python agent library
│   ├── __init__.py
│   ├── agent_base.py             # Base class with hybrid RabbitMQ/env mode
│   ├── rabbit_client.py          # RabbitMQ client wrapper (pika)
│   ├── message_builder.py        # Message construction utilities
│   └── README.md                 # Agent library documentation
├── my_ai_agent_chef/
│   ├── Dockerfile                # Updated: includes agent library
│   ├── chef_agent.py             # 🆕 Updated: hybrid RabbitMQ support
│   └── requirements.txt           # Updated: pika, python-dotenv
├── my_ai_agent_sous/
│   ├── Dockerfile                # Updated: includes agent library
│   ├── sous_agent.py             # 🆕 Updated: hybrid RabbitMQ support
│   └── requirements.txt           # Updated: pika, python-dotenv
├── RABBITMQ_GUIDE.md             # 🆕 Complete RabbitMQ user guide
├── DEPLOYMENT.md                 # 🆕 Production deployment guide
├── IMPLEMENTATION_SUMMARY.md     # 🆕 Technical implementation overview
└── web/                          # Rails 8 web UI
    ├── setup.sh                  # First-run installer
    ├── Gemfile                   # Updated: bunny gem
    ├── app/
    │   ├── controllers/
    │   │   ├── agents_controller.rb
    │   │   ├── agent_runs_controller.rb
    │   │   ├── dashboard_controller.rb
    │   │   └── workflows_controller.rb          # 🆕 Workflow management
    │   ├── jobs/
    │   │   ├── start_agent_job.rb
    │   │   ├── stop_agent_job.rb
    │   │   ├── build_image_job.rb
    │   │   ├── full_cycle_job.rb
    │   │   ├── delegate_task_job.rb             # 🆕 Publish tasks to RabbitMQ
    │   │   └── process_agent_messages_job.rb    # 🆕 Consume RabbitMQ messages
    │   ├── channels/
    │   │   ├── agent_logs_channel.rb
    │   │   ├── agent_communication_channel.rb   # 🆕 Real-time agent messages
    │   │   └── workflow_channel.rb              # 🆕 Real-time workflow updates
    │   ├── models/
    │   │   ├── agent.rb                         # Updated: RabbitMQ fields
    │   │   ├── agent_run.rb                     # Updated: workflow tracking
    │   │   ├── env_var.rb
    │   │   ├── agent_message.rb                 # 🆕 Inter-agent messages
    │   │   ├── workflow.rb                      # 🆕 Multi-step workflows
    │   │   ├── workflow_step.rb                 # 🆕 Individual steps
    │   │   └── message_log.rb                   # 🆕 Message audit trail
    │   ├── views/
    │   │   ├── agents/
    │   │   ├── agent_runs/
    │   │   └── workflows/                       # 🆕 Workflow templates
    │   │       ├── index.html.erb               # Workflow dashboard
    │   │       ├── show.html.erb                # Workflow details
    │   │       ├── new.html.erb                 # Workflow builder
    │   │       └── messages.html.erb            # Communication log
    │   └── helpers/
    │       └── workflows_helper.rb              # 🆕 Workflow view helpers
    ├── lib/
    │   ├── cocina/
    │   │   ├── agent.rb
    │   │   ├── orchestrator.rb
    │   │   ├── agent_adapter.rb
    │   │   └── message_broker.rb                # 🆕 RabbitMQ wrapper
    │   └── tasks/cocina.rake
    ├── db/
    │   ├── migrate/
    │   │   ├── 20240101000001_create_agents.rb
    │   │   ├── 20240101000002_create_env_vars.rb
    │   │   ├── 20240101000003_create_agent_runs.rb
    │   │   ├── 20250407000004_create_agent_messages.rb     # 🆕
    │   │   ├── 20250407000005_create_workflows.rb          # 🆕
    │   │   ├── 20250407000006_create_workflow_steps.rb     # 🆕
    │   │   ├── 20250407000007_create_message_logs.rb       # 🆕
    │   │   └── 20250407000008_extend_agents_for_rabbitmq.rb # 🆕
    ├── app/javascript/controllers/
    │   └── workflow_controller.js                # 🆕 Real-time updates
    └── spec/integration/
        └── workflow_integration_spec.rb          # 🆕 Integration tests
```

---

## 🆕 Multi-Step Workflow Orchestration

Cocina now supports **RabbitMQ-based inter-agent communication** for coordinating complex, multi-step workflows. Agents can work together asynchronously with full message logging and real-time progress tracking.

### Workflow Architecture

```
Web UI (Rails)
    │
    ├─→ Create Workflow with Steps
    │   └─→ Assign agents to each step
    │       └─→ Define dependencies
    │
    ├─→ Start Workflow
    │   └─→ DelegateTaskJob publishes to RabbitMQ
    │
    ├─→ Chef Agent receives task
    │   ├─→ Acknowledges reception
    │   ├─→ Processes with Claude API
    │   └─→ Publishes result to RabbitMQ
    │
    ├─→ ProcessAgentMessagesJob consumes
    │   ├─→ Updates step status
    │   ├─→ Checks dependencies
    │   └─→ Delegates next steps
    │
    └─→ ActionCable broadcasts updates
        └─→ Web UI shows real-time progress
```

### Example Workflow

Create a "Cook a 3-course meal" workflow:

```
Step 1: Chef Agent
├─ Description: "Plan the menu"
└─ Dependencies: None

Step 2: Sous Agent 1
├─ Description: "Cook the main course"
└─ Depends on: Step 1 (menu plan)

Step 3: Sous Agent 2
├─ Description: "Prepare dessert"
└─ Depends on: Step 1 (menu plan)
```

When started:
1. Chef executes immediately (no dependencies)
2. Sous Chef 1 & 2 wait for Chef to complete
3. Once Chef finishes, both Sous Chefs start in parallel
4. All messages logged with full correlation tracking
5. Web UI updates in real-time as steps complete

### Key Capabilities

- **Async communication** — Agents use RabbitMQ for non-blocking messages
- **Dependency resolution** — Automatically execute steps when dependencies met
- **Parallel execution** — Multiple independent steps run simultaneously
- **Message logging** — Every message persisted for audit trails
- **Error handling** — Automatic error notifications and recovery
- **Real-time UI** — WebSocket updates (ActionCable) show progress live
- **Hybrid mode** — Works with or without RabbitMQ (graceful fallback)

### Getting Started with Workflows

1. Start the stack: `docker-compose up -d`
2. Navigate to `http://localhost:3000/workflows/new`
3. Create workflow with name and description
4. Add steps by clicking "Add Step"
5. Select agent for each step
6. Set dependencies between steps
7. Click "Create Workflow"
8. Click "Start Workflow"
9. Watch real-time progress updates
10. View all messages at `/workflows/[id]/messages`

---

## Quick Start

### Option A — CLI (no extra setup)

```bash
git clone https://github.com/zachdwight/cocina-ai-agent-orchestration.git
cd cocina-ai-agent-orchestration

export ANTHROPIC_API_KEY=sk-ant-...

ruby cocina.rb start
```

Cocina builds the Docker images, launches both agents, and monitors them.

---

### Option B — Web UI (without RabbitMQ)

The web UI requires **Ruby 3.1+**. If you're on macOS with an older Ruby:

```bash
# Install rbenv + Ruby 3.3 (one-time)
brew install rbenv ruby-build
rbenv install 3.3.0
rbenv global 3.3.0
rbenv rehash
```

Then set up and launch the Rails app:

```bash
export ANTHROPIC_API_KEY=sk-ant-...

cd web/
bash setup.sh          # installs gems, migrates DB, seeds default agents
bundle exec rails server
```

Open **http://localhost:3000** in your browser.

---

### Option C — Web UI + RabbitMQ Workflows (Recommended)

For the complete experience with multi-step workflows and inter-agent communication:

```bash
export ANTHROPIC_API_KEY=sk-ant-...

# Start the full stack (RabbitMQ + agents + Rails)
docker-compose up -d

# Setup Rails in a separate terminal
cd web/
bundle install
rails db:migrate
rails server
```

Then:
1. Open **http://localhost:3000** in your browser
2. Go to **Workflows** tab
3. Create your first multi-step workflow
4. Agents coordinate automatically via RabbitMQ
5. Watch messages flow in real-time via ActionCable
6. View complete communication logs in the UI

**Features:**
- Create workflows with dependent steps
- Multiple agents work together asynchronously
- Full message audit trail
- Real-time progress tracking
- Works even without RabbitMQ (hybrid mode)

**Monitoring:**
- RabbitMQ Management UI: `http://localhost:15672` (cocina/cocina_pass)
- Rails logs: `tail -f log/development.log`
- Agent logs: `docker logs chef_agent -f`

---

## Web UI Pages

### Agent Management
| Page | URL | What it does |
|---|---|---|
| Dashboard | `/` | Agent cards with live status, quick Start/Stop, recent run history |
| Agents | `/agents` | Full agent list — Start, Stop, Edit, Delete per agent |
| Agent detail | `/agents/:id` | Config, live log terminal, full run history |
| New / Edit agent | `/agents/new` | Form: name, image, command, task, env vars, ports |
| Run detail | `/agents/:id/runs/:id` | Status, duration, exit code, error output |

### 🆕 Workflow Management
| Page | URL | What it does |
|---|---|---|
| Workflows | `/workflows` | Dashboard with workflow list, status, progress bars |
| Workflow detail | `/workflows/:id` | Full workflow progress, step-by-step breakdown, results |
| Create workflow | `/workflows/new` | Multi-step builder — add steps, assign agents, define dependencies |
| Communication log | `/workflows/:id/messages` | View all inter-agent messages, filter by type/status/sender |

### Live Features

- **Status badges** — update automatically via Turbo Streams when a job completes (no refresh needed)
- **Log terminal** — click **Stream** on the agent detail page to tail `docker logs --follow` live in the browser via WebSocket
- **API keys** — automatically masked (`••••••••`) in the UI

### Web UI Screenshots (text mockup)

```
┌─ Dashboard ──────────────────────────────────────────────────────┐
│  🍳 Cocina   Dashboard   Agents               AI Agent Kitchen   │
├──────────────────────────────────────────────────────────────────┤
│  Kitchen Dashboard                              [New Agent]      │
│  2 agents — 1 running                                            │
│                                                                  │
│  ┌─────────────────────┐  ┌─────────────────────┐               │
│  │ chef_agent  ● running│  │ sous_agent  ○ stopped│               │
│  │ my_ai_agent_chef    │  │ my_ai_agent_sous    │               │
│  │ [Stop] [Detail]     │  │ [Start] [Detail]    │               │
│  └─────────────────────┘  └─────────────────────┘               │
│                                                                  │
│  Recent Activity                                                 │
│  chef_agent  start  completed  2 min ago  1.4s                  │
│  sous_agent  stop   completed  5 min ago  0.3s                  │
└──────────────────────────────────────────────────────────────────┘
```

```
┌─ Agent Detail ───────────────────────────────────────────────────┐
│  chef_agent                                      ● running       │
│  Primary Claude agent — plans and coordinates tasks              │
│                                                                  │
│  Image    my_ai_agent_chef:latest                                │
│  Command  python /app/chef_agent.py                              │
│  Task     Plan a 3-course French dinner menu for 4 guests.       │
│                                                                  │
│  [Start] [Stop] [Full Cycle] [Build Image] [Edit]                │
│                                                                  │
│  Live Logs                              [Stream] [Stop]          │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ [Head Chef Agent | ID: chef_001] Starting...               │  │
│  │ [Head Chef Agent] Calling Claude API...                    │  │
│  │ [Head Chef Agent | ID: chef_001] Result:                   │  │
│  │ Here is a classic 3-course French dinner menu...           │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## CLI Reference

```bash
ruby cocina.rb [command] [agent_name] [options]
```

| Command | Description |
|---|---|
| `start` | Build images + start all agents + monitor |
| `stop` | Stop all running agents |
| `start_agent NAME` | Start a single agent by name |
| `stop_agent NAME` | Stop a single agent by name |
| `monitor` | Show running status of all agents |
| `restart` | Stop then start all agents |
| `cleanup` | Remove stopped containers |
| `full_cycle` | Stop → cleanup → build → start → monitor |
| `inventory` | List all registered agents with details |
| `resource_usage` | Live CPU/memory stats via `docker stats` |
| `logs NAME` | Print logs for an agent |
| `logs NAME --follow` | Stream logs live |
| `logs NAME --tail 50` | Show last N lines |

### Rake tasks (from `web/`)

The same operations are available as rake tasks when working within the Rails app:

```bash
cd web/
bundle exec rake cocina:start
bundle exec rake cocina:stop
bundle exec rake 'cocina:start_agent[chef_agent]'
bundle exec rake 'cocina:logs[chef_agent]'
bundle exec rake cocina:monitor
bundle exec rake cocina:full_cycle
bundle exec rake cocina:seed_defaults   # populate DB from cocina.rb defaults
```

---

## Configuration

### CLI — Inline (default)

Agents are defined in `cocina.rb`:

```ruby
{
  name: "chef_agent",
  description: "Primary Claude agent — plans and coordinates tasks",
  image: "my_ai_agent_chef:latest",
  command: "python /app/chef_agent.py",
  env: {
    "ANTHROPIC_API_KEY" => ENV.fetch("ANTHROPIC_API_KEY", ""),
    "AGENT_ID"          => "chef_001",
    "TASK"              => "Plan a 3-course French dinner menu for 4 guests."
  },
  ports: ["8000:8000"]
}
```

### CLI — External JSON

Define agents in `agents_config.json` and load with:

```ruby
orchestrator = DockerAgentOrchestrator.new("agents_config.json")
```

### Web UI — Database

Agents configured through the web UI are stored in SQLite (`web/db/development.sqlite3`). The form lets you set name, image, command, task, env vars (as key-value pairs), and ports. To pre-populate from the CLI defaults:

```bash
cd web/ && bundle exec rake cocina:seed_defaults
```

---

## CLI Example Session

```bash
$ ruby cocina.rb start

--- Building Docker Images ---
Attempting to build image: my_ai_agent_chef:latest
Successfully built my_ai_agent_chef:latest
--- Image Building Complete ---

--- Starting AI Agents ---
Started chef_agent (Container ID: b07d6ff5e36b...)
Started sous_agent (Container ID: d78fd2ce8f8d...)
--- AI Agents Started ---

--- Monitoring AI Agents ---
Agent: chef_agent, Status: Up 2 seconds, ID: b07d6ff5e36b
Agent: sous_agent, Status: Up 2 seconds, ID: d78fd2ce8f8d
--- Monitoring Complete ---
```

```bash
$ ruby cocina.rb logs chef_agent

[Head Chef Agent | ID: chef_001] Starting...
[Head Chef Agent | ID: chef_001] Task: Plan a 3-course French dinner menu for 4 guests.

[Head Chef Agent] Calling Claude API...
[Head Chef Agent | ID: chef_001] Result:

Here is a classic 3-course French dinner menu for 4 guests:

**Entrée** — Soupe à l'oignon gratinée
**Plat**   — Beef bourguignon with pommes purée
**Dessert** — Tarte tatin with crème fraîche

[Head Chef Agent | ID: chef_001] Done. (Input tokens: 42, Output tokens: 318)
```

---

## Adding Your Own Agent

### Simple Agent (Environment Variable Mode)

1. Create a directory and add a `Dockerfile` + agent script:

```bash
mkdir my_new_agent
# add Dockerfile and my_agent.py
```

2. Your agent script needs just two things:

```python
import os, anthropic

client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
task   = os.environ.get("TASK", "Default task here.")

message = client.messages.create(
    model="claude-haiku-4-5-20251001",
    max_tokens=1024,
    system="Your agent's personality and role.",
    messages=[{"role": "user", "content": task}]
)
print(message.content[0].text)
```

3. Add it to `cocina.rb` (CLI) or create it via **New Agent** in the web UI.

### Advanced Agent (RabbitMQ + Workflow Support) 🆕

Use the `cocina_agent_lib` library for RabbitMQ support:

```python
from anthropic import Anthropic
from cocina_agent_lib import CocinaAgentBase

class MyAgent(CocinaAgentBase):
    def __init__(self):
        super().__init__()
        self.anthropic_client = Anthropic(api_key=self.api_key)

    def call_claude(self, task_description):
        message = self.anthropic_client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=2048,
            system="Your agent's personality and role.",
            messages=[{"role": "user", "content": task_description}]
        )
        return message.content[0].text

    def process_message(self, message):
        if message["message_type"] == "task.delegated":
            payload = message.get("payload", {})
            task_id = payload.get("task_id")
            task_desc = payload.get("task_description")

            # Acknowledge, process, and complete
            self.acknowledge_task(task_id, message.get("correlation_id"), message.get("workflow_id"))
            result = self.call_claude(task_desc)
            self.complete_task(task_id, message.get("correlation_id"), message.get("workflow_id"), result)

if __name__ == "__main__":
    agent = MyAgent()
    import sys
    sys.exit(agent.run())
```

The agent automatically:
- Connects to RabbitMQ (if available)
- Falls back to env var mode if RabbitMQ unavailable
- Handles message serialization/deserialization
- Logs structured events
- Reports errors properly

See `cocina_agent_lib/README.md` for full API documentation.

---

## 🆕 Documentation

Comprehensive guides are included in the repository:

| Document | Purpose |
|---|---|
| **RABBITMQ_GUIDE.md** | Complete user guide for workflows and messaging, troubleshooting, monitoring |
| **cocina_agent_lib/README.md** | Python agent library API reference, examples, testing strategies |
| **DEPLOYMENT.md** | Production deployment guide (Docker Compose, Kubernetes, SSL, monitoring) |
| **IMPLEMENTATION_SUMMARY.md** | Technical overview of the RabbitMQ integration architecture |

Start with `RABBITMQ_GUIDE.md` for workflow examples and troubleshooting.

---

## Tips

### General
- **Model selection:** Agents use `claude-haiku-4-5-20251001` by default (fast + cheap). Change to `claude-sonnet-4-6` in the agent `.py` for more complex reasoning.
- **Token usage:** Each agent prints input/output token counts on exit — useful for cost tracking.
- **Multiple tasks:** Run the same image with different `TASK` env vars by giving each agent a unique `name`.
- **docker-compose:** Drop a `docker-compose.yml` in the project root and the CLI will use `docker compose up/down` automatically.
- **Production jobs:** The web UI uses Rails' async job adapter (in-process threads). For production, swap in `solid_queue` or Redis-backed Sidekiq.

### Workflows & RabbitMQ 🆕
- **Hybrid mode:** Agents work with or without RabbitMQ — graceful fallback to env vars if RabbitMQ unavailable.
- **Message logging:** All inter-agent messages are persisted to database — view at `/workflows/:id/messages` for full audit trail.
- **Async by default:** Workflows execute steps asynchronously unless they have dependencies — maximize parallel execution.
- **Monitoring:** RabbitMQ Management UI at `http://localhost:15672` shows queue depth, message rates, connections.
- **Scaling:** Add more agents by duplicating agent service in `docker-compose.yml` with unique `AGENT_ID` and `RABBITMQ_QUEUE`.
- **Error recovery:** Failed steps are logged with full error context — retry manually or implement retry logic in workflows.

---

## License

MIT — cook freely.
