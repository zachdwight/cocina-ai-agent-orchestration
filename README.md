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

| Feature | Description |
|---|---|
| **Claude API** | Agents call `claude-haiku-4-5-20251001` by default — fast and cost-efficient |
| **Task-driven** | Pass any task to an agent via the `TASK` env var |
| **Web UI** | Rails 8 dashboard — start/stop agents, stream live logs, view run history |
| **Live log streaming** | ActionCable WebSocket streams `docker logs --follow` to your browser |
| **Turbo status updates** | Agent status badges update in-place without page refreshes |
| **JSON config** | Define agents inline or in an external `agents_config.json` |
| **Full lifecycle** | Build, start, stop, restart, monitor, logs, cleanup — CLI or UI |
| **Health checks** | Waits for Docker `HEALTHCHECK` before declaring an agent ready |
| **Resource stats** | Real-time CPU/memory via `docker stats` |
| **Compose-aware** | Automatically uses `docker compose` if a compose file is detected |

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
├── my_ai_agent_chef/
│   ├── Dockerfile
│   ├── chef_agent.py             # Head Chef — planner agent (Claude)
│   └── requirements.txt
├── my_ai_agent_sous/
│   ├── Dockerfile
│   ├── sous_agent.py             # Sous Chef — executor agent (Claude)
│   └── requirements.txt
└── web/                          # Rails 8 web UI
    ├── setup.sh                  # First-run installer
    ├── Gemfile
    ├── app/
    │   ├── controllers/          # Dashboard, Agents, AgentRuns
    │   ├── jobs/                 # StartAgent, StopAgent, FullCycle, BuildImage
    │   ├── channels/             # AgentLogsChannel (ActionCable)
    │   ├── models/               # Agent, EnvVar, AgentRun
    │   └── views/                # Tailwind-styled UI
    ├── lib/
    │   ├── cocina/               # Extracted domain classes
    │   │   ├── agent.rb          # Cocina::Agent value object
    │   │   ├── orchestrator.rb   # Docker command wrapper
    │   │   └── agent_adapter.rb  # AR Agent → Cocina::Agent bridge
    │   └── tasks/cocina.rake     # Rake tasks (CLI parity)
    └── db/migrate/               # Agent, EnvVar, AgentRun tables
```

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

### Option B — Web UI

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

## Web UI Pages

| Page | URL | What it does |
|---|---|---|
| Dashboard | `/` | Agent cards with live status, quick Start/Stop, recent run history |
| Agents | `/agents` | Full agent list — Start, Stop, Edit, Delete per agent |
| Agent detail | `/agents/:id` | Config, live log terminal, full run history |
| New / Edit agent | `/agents/new` | Form: name, image, command, task, env vars, ports |
| Run detail | `/agents/:id/runs/:id` | Status, duration, exit code, error output |

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

---

## Tips

- **Model selection:** Agents use `claude-haiku-4-5-20251001` by default (fast + cheap). Change to `claude-sonnet-4-6` in the agent `.py` for more complex reasoning.
- **Token usage:** Each agent prints input/output token counts on exit — useful for cost tracking.
- **Multiple tasks:** Run the same image with different `TASK` env vars by giving each agent a unique `name`.
- **docker-compose:** Drop a `docker-compose.yml` in the project root and the CLI will use `docker compose up/down` automatically.
- **Production jobs:** The web UI uses Rails' async job adapter (in-process threads). For production, swap in `solid_queue` or Redis-backed Sidekiq.

---

## License

MIT — cook freely.
