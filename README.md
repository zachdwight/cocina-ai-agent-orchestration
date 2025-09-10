# `cocina` - Docker Agent Orchestrator

`cocina.rb` is a Ruby script designed to orchestrate the lifecycle of multiple AI agents running in Docker containers. It allows you to build, start, stop, monitor, and clean up your agents with simple commands.

## Features

* **Agent Configuration:** Define your AI agents, their Docker images, commands, environment variables, and exposed ports directly within the script or via an external JSON configuration file.
* **Docker Integration:** Leverages `docker build`, `docker run`, `docker stop`, and `docker ps` commands to manage containers.
* **Lifecycle Management:** Supports various actions:
    * **Start:** Builds images (if Dockerfile found) and starts all defined agents.
    * **Start_Agent:** Starts specific agent by name.
    * **Stop:** Halts all running agent containers.
    * **Stop_Agent:** Stops specific agent by name.
    * **Monitor:** Checks and reports the status of your agents.
    * **Restart:** Stops and then restarts all agents.
    * **Cleanup:** Removes stopped agent containers.
    * **Full Cycle:** Performs a stop, cleanup, build, and then start operation.
    * **Inventory:** List out all agents (w/ details) that are registered.
* **Error Handling:** Provides basic error reporting for Docker commands and configuration parsing.

## Prerequisites

---

Before using `cocina.rb`, ensure you have the following installed:

* **Ruby:** Version 2.x or higher.
* **Docker:** Docker Engine installed and running on your system.

## Setup

---

1.  **Clone or Download:** Get the `cocina.rb` script.
2.  **Agent Dockerfiles:** Create `Dockerfile`s for your AI agents. By default, the script expects a directory named after your image (without the tag) containing the Dockerfile.
    * For `my_ai_agent_chef:latest`, create a directory `./my_ai_agent_chef/` with its `Dockerfile` inside.
    * For `my_ai_agent_sous:latest`, create a directory `./my_ai_agent_sous/` with its `Dockerfile` inside.
    * **Example Directory Structure:**
        ```
        .
        ├── cocina.rb
        ├── my_ai_agent_chef/
        │   └── Dockerfile
        │   └── chef_agent.py
        └── my_ai_agent_sous/
            └── Dockerfile
            └── sous_agent.py
        ```
3.  **Pre-build (Optional but Recommended):** You can pre-build your agent images manually before running `cocina.rb` for the first time, or let the script attempt to build them during the `start` or `full_cycle` actions.

    ```bash
    docker build -t my_ai_agent_chef:latest ./my_ai_agent_chef
    docker build -t my_ai_agent_sous:latest ./my_ai_agent_sous
    ```

## Configuration

---

### Default Configuration

The script comes with a default set of agents defined within the `DockerAgentOrchestrator` class:

```ruby
@agents = [
        {
          name: "chef_agent",
          description: "Primary agent utilizing ChatGPT or Gemini or etc etc etc", #describe the agent for inventory purposes / audit
          build: "prod", #define if agent is prod or test or something else
          externals: "none", # list if any RAG resources are involved with agent
          image: "my_ai_agent_chef:latest", # Replace with your actual agent image
          command: "python /app/chef_agent.py", # Command to run inside the container
          env: { "API_KEY" => "some_key_alpha", "AGENT_ID" => "chef_001" },
          ports: ["8000:8000"] # Example: exposing port 8000
        },
        {
          name: "sous_agent",
          description: "Agent to help primary.", #describe the agent for inventory purposes / audit
          build: "prod", #define if agent is prod or test or something else
          externals: "none", # list if any RAG resources are involved with agent
          image: "my_ai_agent_sous:latest", # Replace with your actual agent image
          command: "python /app/sous_agent.py",
          env: { "API_KEY" => "some_key_beta", "AGENT_ID" => "sous_001" },
          ports: [] # No ports exposed for this agent
        }
      ]
```

Optional: External JSON Configuration (Recommended for Production)

For more flexible management, you can define your agents in a separate JSON file (e.g., `agents_config.json`) and pare details you don't need:
```json
[
  {
    "name": "chef_agent",
    "image": "my_ai_agent_chef:latest",
    "command": "python /app/chef_agent.py",
    "env": { "API_KEY": "your_chef_api_key", "AGENT_ID": "chef_001" },
    "ports": ["8000:8000"]
  },
  {
    "name": "sous_agent",
    "image": "my_ai_agent_sous:latest",
    "command": "python /app/sous_agent.py",
    "env": { "API_KEY": "your_sous_api_key", "AGENT_ID": "sous_001" },
    "ports": []
  },
  {
    "name": "data_logger",
    "image": "my_data_logger:1.0",
    "command": "node /app/logger.js",
    "env": { "LOG_LEVEL": "info" },
    "ports": []
  }
]

```

To use an external configuration file, initialize the `DockerAgentOrchestrator` with the file path:
```ruby
orchestrator = DockerAgentOrchestrator.new("agents_config.json")
```

## Usage

---

Run the script from your terminal, passing one of the supported actions as an argument:

```bash
ruby cocina.rb [action]
```

Available Actions:
- `start` : Builds Docker images (if their context directory and Dockerfile exist) and then starts all defined AI agent containers.
- `stop` : Stops all currently running AI agent containers managed by Cocina.
- `start_agent[agent_name]` : Start specific agent.
- `stop_agent[agent_name]` : Stop specific agent.
- `monitor` : Displays the current running status (container ID, status, name) of all configured agents.
- `restart` : Stops all agents and then starts them again.
- `clean_up` : Attempts to remove any stopped containers associated with the defined agents. 
- `full_cycle` : Executes a complete lifecycle: stops, cleans up, builds (if needed), and then starts all agents. This is useful for a fresh deployment.
- `inventory` : Lists out all registered agents and additional details.
---

## Example 

```bash
me@Boring-iMac cocina-ai-agent-orchestration % ruby cocina.rb start

--- Building Docker Images ---
Attempting to build image: my_ai_agent_chef:latest from ./my_ai_agent_chef
Successfully built image: my_ai_agent_chef:latest
Attempting to build image: my_ai_agent_sous:latest from ./my_ai_agent_sous
Successfully built image: my_ai_agent_sous:latest
--- Image Building Complete ---

--- Starting AI Agents ---
Starting container for chef_agent...
Started chef_agent (Container ID: b07d6ff5e36b8c7faf55c780072b2468e72d13dab327fe5652c17b4a81ec72b7)
Starting container for sous_agent...
Started sous_agent (Container ID: d78fd2ce8f8dc3e077f51d93426091fd054df517019f96a2bd23251539bb75ee)
--- AI Agents Started ---

--- Monitoring AI Agents ---
Agent: chef_agent, Status: Up Less than a second, ID: b07d6ff5e36b
Agent: sous_agent, Status: Up Less than a second, ID: d78fd2ce8f8d
--- Monitoring Complete ---

```

Let a few minutes pass by for the agents to complete their tasks...

``` bash
me@Boring-iMac cocina-ai-agent-orchestration % ruby cocina.rb monitor

--- Monitoring AI Agents ---
Agent: chef_agent is not running.
Agent: sous_agent is not running.
No AI agents are currently running.
--- Monitoring Complete ---
```

List out the inventory of agents to confirm details...

``` bash
me@Boring-iMac cocina-ai-agent-orchestration % ruby cocina.rb inventory

--- AI Agent Inventory ---
Total Agents : 2
#1:
  Name: chef_agent
  Description: Primary agent utilizing ChatGPT or Gemini or etc etc etc
  Image: my_ai_agent_chef:latest
  Build: prod
  Externals: none
#2:
  Name: sous_agent
  Description: Agent to help primary.
  Image: my_ai_agent_sous:latest
  Build: prod
  Externals: none
--- Inventory Complete ---
```
