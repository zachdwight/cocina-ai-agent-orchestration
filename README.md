# `cocina` - Docker Agent Orchestrator

`cocina.rb` is a Ruby script designed to orchestrate the lifecycle of multiple AI agents running in Docker containers. It allows you to build, start, stop, monitor, and clean up your agents with simple commands.

## Features

* **Agent Configuration:** Define your AI agents, their Docker images, commands, environment variables, and exposed ports directly within the script or via an external JSON configuration file.
* **Docker Integration:** Leverages `docker build`, `docker run`, `docker stop`, and `docker ps` commands to manage containers.
* **Lifecycle Management:** Supports various actions:
    * **Start:** Builds images (if Dockerfile found) and starts all defined agents.
    * **Stop:** Halts all running agent containers.
    * **Monitor:** Checks and reports the status of your agents.
    * **Restart:** Stops and then restarts all agents.
    * **Cleanup:** Removes stopped agent containers.
    * **Full Cycle:** Performs a stop, cleanup, build, and then start operation.
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
    image: "my_ai_agent_chef:latest",
    command: "python /app/chef_agent.py",
    env: { "API_KEY" => "some_key_alpha", "AGENT_ID" => "chef_001" },
    ports: ["8000:8000"]
  },
  {
    name: "sous_agent",
    image: "my_ai_agent_sous:latest",
    command: "python /app/sous_agent.py",
    env: { "API_KEY" => "some_key_beta", "AGENT_ID" => "sous_001" },
    ports: []
  }
]
```

Optional: External JSON Configuration (Recommended for Production)

For more flexible management, you can define your agents in a separate JSON file (e.g., `agents_config.json`):
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
- `monitor` : Displays the current running status (container ID, status, name) of all configured agents.
- `restart` : Stops all agents and then starts them again.
- `clean_up` : Attempts to remove any stopped containers associated with the defined agents. 
- `full_cycle` : Executes a complete lifecycle: stops, cleans up, builds (if needed), and then starts all agents. This is useful for a fresh deployment.
