# 🍳 `cocina` — AI Agent Orchestrator

> *cocina* (Spanish) — _kitchen_. Because great AI agents, like great meals, need a well-run kitchen.

`cocina.rb` is a Ruby script that orchestrates the lifecycle of multiple AI agents running in Docker containers. Each agent is a containerized Claude-powered worker with its own role, task, and personality. Cocina handles the boring parts — building, starting, stopping, monitoring, and cleaning up — so your agents can focus on thinking.

---

## How It Works

```
┌─────────────────────────────────────────┐
│              cocina.rb                  │
│         (the expeditor)                 │
└────────────┬──────────────┬────────────┘
             │              │
     ┌───────▼──────┐ ┌─────▼────────┐
     │  chef_agent  │ │  sous_agent  │
     │  Docker ctr  │ │  Docker ctr  │
     │  Claude API  │ │  Claude API  │
     └──────────────┘ └──────────────┘
```

The **Head Chef** agent plans and coordinates. The **Sous Chef** executes specific sub-tasks. Both call the Claude API and report their results to stdout (streamed via `docker logs`). Add as many agents as your kitchen needs.

---

## Features

| Feature | Description |
|---|---|
| **Claude API** | Agents call `claude-haiku-4-5-20251001` by default — fast and cost-efficient |
| **Task-driven** | Pass any task to an agent via the `TASK` env var |
| **JSON config** | Define agents inline or in an external `agents_config.json` |
| **Full lifecycle** | Build, start, stop, restart, monitor, logs, cleanup — one command each |
| **Health checks** | Waits for Docker `HEALTHCHECK` to pass before declaring an agent ready |
| **Resource stats** | Real-time CPU/memory via `docker stats` |
| **Compose-aware** | Automatically uses `docker compose` if a compose file is detected |

---

## Prerequisites

- **Ruby** 2.7+
- **Docker** Engine running
- **Anthropic API key** — [get one here](https://console.anthropic.com/)

---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/zachdwight/cocina-ai-agent-orchestration.git
cd cocina-ai-agent-orchestration
```

### 2. Set your API key

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

Cocina forwards this from your host environment into each container automatically. Never hardcode keys.

### 3. Run it

```bash
ruby cocina.rb start
```

That's it. Cocina builds the Docker images (if needed), launches the agents, and monitors them.

---

## Project Structure

```
.
├── cocina.rb                   # Orchestrator — the kitchen manager
├── my_ai_agent_chef/
│   ├── Dockerfile
│   ├── chef_agent.py           # Head Chef — planner agent (Claude)
│   └── requirements.txt
└── my_ai_agent_sous/
    ├── Dockerfile
    ├── sous_agent.py           # Sous Chef — executor agent (Claude)
    └── requirements.txt
```

---

## Configuration

### Inline (default)

Agents are defined in `cocina.rb` with sensible defaults:

```ruby
{
  name: "chef_agent",
  description: "Primary Claude agent — plans and coordinates tasks",
  build: "prod",
  externals: "none",
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

Change `TASK` to give your agent a different job. Change the system prompt in the Python file to change its personality.

### External JSON (recommended for production)

Define agents in `agents_config.json`:

```json
[
  {
    "name": "chef_agent",
    "description": "Head Chef — plans the menu",
    "image": "my_ai_agent_chef:latest",
    "command": "python /app/chef_agent.py",
    "env": {
      "ANTHROPIC_API_KEY": "your_key_here",
      "AGENT_ID": "chef_001",
      "TASK": "Design a 5-course tasting menu for a Michelin-star dinner."
    },
    "ports": ["8000:8000"]
  },
  {
    "name": "sous_agent",
    "description": "Sous Chef — executes the recipes",
    "image": "my_ai_agent_sous:latest",
    "command": "python /app/sous_agent.py",
    "env": {
      "ANTHROPIC_API_KEY": "your_key_here",
      "AGENT_ID": "sous_001",
      "TASK": "Write a detailed recipe for duck confit with cherry reduction."
    },
    "ports": []
  }
]
```

Load it with:

```ruby
orchestrator = DockerAgentOrchestrator.new("agents_config.json")
```

---

## Commands

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

---

## Example Session

```bash
# Fire up the kitchen
$ ruby cocina.rb start

--- Building Docker Images ---
Attempting to build image: my_ai_agent_chef:latest
Successfully built my_ai_agent_chef:latest
Attempting to build image: my_ai_agent_sous:latest
Successfully built my_ai_agent_sous:latest
--- Image Building Complete ---

--- Starting AI Agents ---
Starting container for chef_agent...
Started chef_agent (Container ID: b07d6ff5e36b...)
No HEALTHCHECK defined for chef_agent; skipping health wait.
Starting container for sous_agent...
Started sous_agent (Container ID: d78fd2ce8f8d...)
No HEALTHCHECK defined for sous_agent; skipping health wait.
--- AI Agents Started ---

--- Monitoring AI Agents ---
Agent: chef_agent, Status: Up 2 seconds, ID: b07d6ff5e36b
Agent: sous_agent, Status: Up 2 seconds, ID: d78fd2ce8f8d
--- Monitoring Complete ---
```

```bash
# Watch what the Head Chef is thinking
$ ruby cocina.rb logs chef_agent

[Head Chef Agent | ID: chef_001] Starting...
[Head Chef Agent | ID: chef_001] Task: Plan a 3-course French dinner menu for 4 guests.

[Head Chef Agent] Calling Claude API...
[Head Chef Agent | ID: chef_001] Result:

Here is a classic 3-course French dinner menu for 4 guests:

**Entrée**
Soupe à l'oignon gratinée — French onion soup with Gruyère crouton
...

[Head Chef Agent | ID: chef_001] Done. (Input tokens: 42, Output tokens: 318)
```

```bash
# Check the inventory
$ ruby cocina.rb inventory

--- AI Agent Inventory ---
Total Agents: 2
#1:
  Name:        chef_agent
  Description: Primary Claude agent — plans and coordinates tasks
  Image:       my_ai_agent_chef:latest
  Build:       prod
  Externals:   none
#2:
  Name:        sous_agent
  Description: Secondary Claude agent — executes specific sub-tasks
  Image:       my_ai_agent_sous:latest
  Build:       prod
  Externals:   none
--- Inventory Complete ---
```

```bash
# Stop a specific agent
$ ruby cocina.rb stop_agent sous_agent

--- Stopping AI Agent: sous_agent ---
Stopped sous_agent.
--- AI Agent Stopped ---
```

```bash
# Full reset and redeploy
$ ruby cocina.rb full_cycle
```

---

## Adding Your Own Agent

1. Create a directory: `mkdir my_new_agent`
2. Add a `Dockerfile` and your agent script
3. Add the agent to the config (inline or JSON) with its `TASK` and `ANTHROPIC_API_KEY`
4. Run `ruby cocina.rb start_agent my_new_agent`

The agent script just needs to read `ANTHROPIC_API_KEY` and `TASK` from the environment and call the Claude API. See `chef_agent.py` or `sous_agent.py` for a working template.

---

## Tips

- **Model selection:** Agents use `claude-haiku-4-5-20251001` by default (fast + cheap). Swap to `claude-sonnet-4-6` in the agent `.py` for more complex reasoning tasks.
- **Token usage:** Each agent prints input/output token counts on exit — useful for cost tracking.
- **Multiple tasks:** Run multiple instances of the same agent image with different `TASK` env vars by giving each a unique `name`.
- **docker-compose:** Drop a `docker-compose.yml` in the project root and `cocina` will use `docker compose up/down` automatically.

---

## License

MIT — cook freely.
