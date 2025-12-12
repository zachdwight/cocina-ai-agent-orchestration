# cocina.rb

require 'json' # For potential future configuration loading
require 'open3' # To execute shell commands and capture output/errors
require 'shellwords'

#keep in mind you could pre-build your agents in any location and adjust accordingly
#docker build -t my_ai_agent_chef:latest ./my_ai_agent_chef
#docker build -t my_ai_agent_sous:latest ./my_ai_agent_sous
class Agent
  attr_reader :name, :description, :image, :command, :env, :ports, :build, :externals

  def initialize(h)
    @name        = h[:name]
    @description = h[:description]
    @image       = h[:image]
    @command     = h[:command]
    @env         = h[:env] || {}
    @ports       = h[:ports] || []
    @build       = h[:build]
    @externals   = h[:externals]
  end

  def env_flags
    env.flat_map { |k,v| ["-e", "#{k}=#{v}"] }
  end

  def port_flags
    ports.flat_map { |p| ["-p", p] }
  end
end


class DockerAgentOrchestrator
  def initialize(config_file = nil)
    @agents = []

    if config_file
      load_config(config_file)
    else
      default_agents = [
        {
          name: "chef_agent",
          description: "Primary agent utilizing ChatGPT or Gemini or etc etc etc",
          build: "prod",
          externals: "none",
          image: "my_ai_agent_chef:latest",
          command: "python /app/chef_agent.py",
          env: { "API_KEY" => "some_key_alpha", "AGENT_ID" => "chef_001" },
          ports: ["8000:8000"]
        },
        {
          name: "sous_agent",
          description: "Agent to help primary",
          build: "prod",
          externals: "none",
          image: "my_ai_agent_sous:latest",
          command: "python /app/sous_agent.py",
          env: { "API_KEY" => "some_key_beta", "AGENT_ID" => "sous_001" },
          ports: []
        }
      ]

      @agents = default_agents.map { |a| Agent.new(a) }
    end
  end

  #
  # Quick Win #2: compose auto-detection
  #
  def use_compose?
    File.exist?("docker-compose.yml") || File.exist?("compose.yaml")
  end

  def load_config(file_path)
    unless File.exist?(file_path)
      puts "Error: Configuration file '#{file_path}' not found."
      exit 1
    end

    begin
      raw = JSON.parse(File.read(file_path), symbolize_names: true)
      @agents = raw.map { |agent| Agent.new(agent) }
      puts "Loaded agent configurations from #{file_path}"
    rescue JSON::ParserError => e
      puts "Error parsing configuration file: #{e.message}"
      exit 1
    end
  end

  #
  # Quick Win #3 — Command wrapper with nicer output
  #
  def run_command(cmd_array)
    stdout, stderr, status = Open3.capture3(*cmd_array)
    unless status.success?
      puts "Command failed: #{cmd_array.shelljoin}"
      puts "STDOUT: #{stdout}" unless stdout.empty?
      puts "STDERR: #{stderr}" unless stderr.empty?
    end

    [stdout.strip, stderr.strip, status.success?]
  end

  #
  # Quick Win #4: docker healthcheck wait
  #
def wait_for_healthy(agent, timeout: 25)
  start_time = Time.now

  loop do
    # First: check whether container even HAS a Health section
    inspect_cmd = ["docker", "inspect", "--format={{json .State.Health}}", agent.name]
    stdout, _, _ = run_command(inspect_cmd)

    # If Health is null or empty → no healthcheck → skip waiting
    if stdout.nil? || stdout.empty? || stdout == "null"
      puts "No HEALTHCHECK defined for #{agent.name}; skipping health wait."
      return true
    end

    # If Health exists, then check the status
    inspect_cmd = ["docker", "inspect", "--format={{.State.Health.Status}}", agent.name]
    health_status, _, _ = run_command(inspect_cmd)

    return true if health_status == "healthy"

    break if Time.now - start_time > timeout
    sleep 1
  end

  false
end

  #
  # Build images (unchanged, except using new Agent class)
  #
  def build_images
    puts "\n--- Building Docker Images ---"

    @agents.each do |agent|
      image_name_without_tag = agent.image.split(':').first
      dockerfile_path = "./#{image_name_without_tag}"

      if File.directory?(dockerfile_path)
        puts "Attempting to build image: #{agent.image}"

        cmd = ["docker", "build", "-t", agent.image, dockerfile_path]
        _, _, success = run_command(cmd)

        puts(success ? "Successfully built #{agent.image}" : "Failed to build #{agent.image}")
      else
        puts "Skipping #{agent.image}; no Dockerfile context exists."
      end
    end

    puts "--- Image Building Complete ---"
  end

  #
  # Start all agents
  #
  def start_agents
    if use_compose?
      puts "\n--- Starting via docker compose ---"
      system("docker compose up -d")
      return
    end

    puts "\n--- Starting AI Agents ---"
    @agents.each { |agent| start_single(agent) }
    puts "--- AI Agents Started ---"
  end

  #
  # Helper for starting a single agent (used by both start & start_agent)
  #
  def start_single(agent)
    args = [
      "docker", "run", "-d", "--rm",
      "--name", agent.name,
      *agent.env_flags,
      *agent.port_flags,
      agent.image,
      *Shellwords.split(agent.command)
    ]

    puts "Starting container for #{agent.name}..."
    stdout, _, success = run_command(args)

    if success
      puts "Started #{agent.name} (Container ID: #{stdout})"
      wait_for_healthy(agent)
    else
      puts "Failed to start #{agent.name}."
    end
  end

  def start_agent(name)
    agent = @agents.find { |a| a.name == name }
    return puts "Agent '#{name}' not found." unless agent

    puts "\n--- Starting AI Agent: #{name} ---"
    start_single(agent)
    puts "--- AI Agent Started ---"
  end

  #
  # Monitor
  #
  def monitor_agents
    puts "\n--- Monitoring AI Agents ---"

    @agents.each do |agent|
      cmd = [
        "docker", "ps",
        "-f", "name=^/#{agent.name}$",
        "--format", "{{.ID}}\t{{.Status}}\t{{.Names}}"
      ]

      stdout, _, _ = run_command(cmd)

      if stdout.empty?
        puts "Agent: #{agent.name} is not running."
      else
        id, status, name = stdout.split("\t")
        puts "Agent: #{name}, Status: #{status}, ID: #{id}"
      end
    end

    puts "--- Monitoring Complete ---"
  end

  #
  # Logs
  #
  def agent_logs(name, follow=false, tail=nil)
    puts "\n--- Displaying Logs for AI Agent: #{name} ---"

    args = ["docker", "logs", name]
    args << "-f" if follow
    args += ["--tail", tail.to_s] if tail

    if follow
      exec(*args)
    else
      stdout, stderr, success = run_command(args)
      puts(success ? stdout : "Error: #{stderr}")
    end

    puts "--- Logs Display Complete ---"
  end

  #
  # Stop agents
  #
  def stop_agents
    puts "\n--- Stopping AI Agents ---"
    if use_compose?
      system("docker compose down")
      return
    end

    @agents.each do |agent|
      run_command(["docker", "stop", agent.name])
      puts "Stopped #{agent.name}."
    end

    puts "--- AI Agents Stopped ---"
  end

  def stop_agent(name)
    puts "\n--- Stopping AI Agent: #{name} ---"
    run_command(["docker", "stop", name])
    puts "--- AI Agent Stopped ---"
  end

  def cleanup_containers
    puts "\n--- Cleaning Up Docker Containers ---"

    @agents.each do |agent|
      stdout, stderr, _ = run_command(["docker", "rm", agent.name])
      if stderr.include?("No such container")
        puts "Container #{agent.name} does not exist."
      else
        puts "Removed #{agent.name}"
      end
    end

    puts "--- Cleanup Complete ---"
  end

  #
  # Inventory
  #
  def list_agents
    puts "\n--- AI Agent Inventory ---"

    @agents.each_with_index do |agent, i|
      puts "##{i+1}"
      puts "  Name: #{agent.name}"
      puts "  Description: #{agent.description}"
      puts "  Image: #{agent.image}"
      puts "  Build: #{agent.build}"
      puts "  Externals: #{agent.externals}"
    end

    puts "--- Inventory Complete ---"
  end

  #
  # Resource usage
  #
  def resource_usage
    puts "\n--- AI Agent Resource Usage ---"

    running = @agents.map(&:name)
    args = [
      "docker", "stats", "--no-stream",
      "--format", "table {{.ID}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}",
      *running
    ]

    stdout, _, success = run_command(args)
    puts stdout if success
  end

  #
  # Orchestration entrypoint
  #
  def orchestrate(action, agent_name=nil, options={})
    case action
    when :start       then build_images; start_agents; monitor_agents
    when :stop        then stop_agents
    when :stop_agent  then stop_agent(agent_name)
    when :start_agent then start_agent(agent_name)
    when :monitor     then monitor_agents
    when :restart     then stop_agents; start_agents; monitor_agents
    when :cleanup     then cleanup_containers
    when :full_cycle  then stop_agents; cleanup_containers; build_images; start_agents; monitor_agents
    when :inventory   then list_agents
    when :resource_usage then resource_usage
    when :logs        then agent_logs(agent_name, options[:follow], options[:tail])
    else
      puts "Unknown action: #{action}"
    end
  end
end


#
# CLI Part – unchanged except for formatting
#
if __FILE__ == $0
  orchestrator = DockerAgentOrchestrator.new

  case ARGV[0]
  when "start" then orchestrator.orchestrate(:start)
  when "stop"  then orchestrator.orchestrate(:stop)

  when "start_agent"
    name = ARGV[1] or abort("Usage: start_agent [name]")
    orchestrator.orchestrate(:start_agent, name)

  when "stop_agent"
    name = ARGV[1] or abort("Usage: stop_agent [name]")
    orchestrator.orchestrate(:stop_agent, name)

  when "monitor"       then orchestrator.orchestrate(:monitor)
  when "restart"       then orchestrator.orchestrate(:restart)
  when "cleanup"       then orchestrator.orchestrate(:cleanup)
  when "full_cycle"    then orchestrator.orchestrate(:full_cycle)
  when "inventory"     then orchestrator.orchestrate(:inventory)
  when "resource_usage" then orchestrator.orchestrate(:resource_usage)

  when "logs"
    name = ARGV[1] or abort("Usage: logs [name] [--follow] [--tail N]")
    opts = {}
    opts[:follow] = ARGV.include?("--follow")
    if idx = ARGV.index("--tail")
      opts[:tail] = ARGV[idx+1].to_i
    end
    orchestrator.orchestrate(:logs, name, opts)

  else
    puts "Usage: ruby cocina.rb [start|start_agent name|stop|stop_agent name|monitor|restart|cleanup|full_cycle|inventory|resource_usage|logs name]"
  end
end

