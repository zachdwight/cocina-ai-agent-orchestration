# cocina.rb

require 'json'
require 'open3'
require 'shellwords'

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
    env.flat_map { |k, v| ["-e", "#{k}=#{v}"] }
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
        },
        {
          name: "sous_agent",
          description: "Secondary Claude agent — executes specific sub-tasks",
          build: "prod",
          externals: "none",
          image: "my_ai_agent_sous:latest",
          command: "python /app/sous_agent.py",
          env: {
            "ANTHROPIC_API_KEY" => ENV.fetch("ANTHROPIC_API_KEY", ""),
            "AGENT_ID"          => "sous_001",
            "TASK"              => "Write a detailed recipe for beef bourguignon."
          },
          ports: []
        }
      ]

      @agents = default_agents.map { |a| Agent.new(a) }
    end
  end

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

  def run_command(cmd_array)
    stdout, stderr, status = Open3.capture3(*cmd_array)
    unless status.success?
      puts "Command failed: #{cmd_array.shelljoin}"
      puts "STDOUT: #{stdout}" unless stdout.empty?
      puts "STDERR: #{stderr}" unless stderr.empty?
    end
    [stdout.strip, stderr.strip, status.success?]
  end

  def wait_for_healthy(agent, timeout: 25)
    start_time = Time.now

    loop do
      inspect_cmd = ["docker", "inspect", "--format={{json .State.Health}}", agent.name]
      stdout, _, _ = run_command(inspect_cmd)

      if stdout.nil? || stdout.empty? || stdout == "null"
        puts "No HEALTHCHECK defined for #{agent.name}; skipping health wait."
        return true
      end

      inspect_cmd = ["docker", "inspect", "--format={{.State.Health.Status}}", agent.name]
      health_status, _, _ = run_command(inspect_cmd)

      return true if health_status == "healthy"
      break if Time.now - start_time > timeout
      sleep 1
    end

    false
  end

  def build_images
    puts "\n--- Building Docker Images ---"

    @agents.each do |agent|
      image_name_without_tag = agent.image.split(':').first
      dockerfile_path = "./#{image_name_without_tag}"

      if File.directory?(dockerfile_path)
        puts "Attempting to build image: #{agent.image}"
        _, _, success = run_command(["docker", "build", "-t", agent.image, dockerfile_path])
        puts(success ? "Successfully built #{agent.image}" : "Failed to build #{agent.image}")
      else
        puts "Skipping #{agent.image}; no Dockerfile context found."
      end
    end

    puts "--- Image Building Complete ---"
  end

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

  def monitor_agents
    puts "\n--- Monitoring AI Agents ---"
    any_running = false

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
        any_running = true
      end
    end

    puts "No AI agents are currently running." unless any_running
    puts "--- Monitoring Complete ---"
  end

  def agent_logs(name, follow = false, tail = nil)
    puts "\n--- Displaying Logs for AI Agent: #{name} ---"

    args = ["docker", "logs", name]
    args << "-f" if follow
    args += ["--tail", tail.to_s] if tail

    if follow
      exec(*args)
    else
      stdout, stderr, success = run_command(args)
      puts(success ? stdout : "Error: #{stderr}")
      puts "--- Logs Display Complete ---"
    end
  end

  def stop_agents
    puts "\n--- Stopping AI Agents ---"

    if use_compose?
      system("docker compose down")
      return
    end

    @agents.each do |agent|
      _, _, success = run_command(["docker", "stop", agent.name])
      puts(success ? "Stopped #{agent.name}." : "Could not stop #{agent.name} (may not be running).")
    end

    puts "--- AI Agents Stopped ---"
  end

  def stop_agent(name)
    puts "\n--- Stopping AI Agent: #{name} ---"
    _, _, success = run_command(["docker", "stop", name])
    puts(success ? "Stopped #{name}." : "Could not stop #{name} (may not be running).")
    puts "--- AI Agent Stopped ---"
  end

  def cleanup_containers
    puts "\n--- Cleaning Up Docker Containers ---"

    @agents.each do |agent|
      _, _, success = run_command(["docker", "rm", agent.name])
      puts(success ? "Removed #{agent.name}." : "Could not remove #{agent.name} (may not exist or still running).")
    end

    puts "--- Cleanup Complete ---"
  end

  def list_agents
    puts "\n--- AI Agent Inventory ---"
    puts "Total Agents: #{@agents.size}"

    @agents.each_with_index do |agent, i|
      puts "##{i + 1}:"
      puts "  Name:        #{agent.name}"
      puts "  Description: #{agent.description}"
      puts "  Image:       #{agent.image}"
      puts "  Build:       #{agent.build}"
      puts "  Externals:   #{agent.externals}"
    end

    puts "--- Inventory Complete ---"
  end

  def resource_usage
    puts "\n--- AI Agent Resource Usage ---"

    running = @agents.map(&:name)
    args = [
      "docker", "stats", "--no-stream",
      "--format", "table {{.ID}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}",
      *running
    ]

    stdout, _, success = run_command(args)
    puts(success ? stdout : "No resource data available (agents may not be running).")
  end

  def orchestrate(action, agent_name = nil, options = {})
    case action
    when :start          then build_images; start_agents; monitor_agents
    when :stop           then stop_agents
    when :stop_agent     then stop_agent(agent_name)
    when :start_agent    then start_agent(agent_name)
    when :monitor        then monitor_agents
    when :restart        then stop_agents; start_agents; monitor_agents
    when :cleanup        then cleanup_containers
    when :full_cycle     then stop_agents; cleanup_containers; build_images; start_agents; monitor_agents
    when :inventory      then list_agents
    when :resource_usage then resource_usage
    when :logs           then agent_logs(agent_name, options[:follow], options[:tail])
    else
      puts "Unknown action: #{action}"
    end
  end
end


if __FILE__ == $0
  orchestrator = DockerAgentOrchestrator.new

  case ARGV[0]
  when "start"  then orchestrator.orchestrate(:start)
  when "stop"   then orchestrator.orchestrate(:stop)

  when "start_agent"
    name = ARGV[1] or abort("Usage: ruby cocina.rb start_agent [name]")
    orchestrator.orchestrate(:start_agent, name)

  when "stop_agent"
    name = ARGV[1] or abort("Usage: ruby cocina.rb stop_agent [name]")
    orchestrator.orchestrate(:stop_agent, name)

  when "monitor"        then orchestrator.orchestrate(:monitor)
  when "restart"        then orchestrator.orchestrate(:restart)
  when "cleanup"        then orchestrator.orchestrate(:cleanup)
  when "full_cycle"     then orchestrator.orchestrate(:full_cycle)
  when "inventory"      then orchestrator.orchestrate(:inventory)
  when "resource_usage" then orchestrator.orchestrate(:resource_usage)

  when "logs"
    name = ARGV[1] or abort("Usage: ruby cocina.rb logs [name] [--follow] [--tail N]")
    opts = {}
    opts[:follow] = ARGV.include?("--follow")
    if (idx = ARGV.index("--tail"))
      opts[:tail] = ARGV[idx + 1].to_i
    end
    orchestrator.orchestrate(:logs, name, opts)

  else
    puts "Usage: ruby cocina.rb [start|start_agent name|stop|stop_agent name|monitor|restart|cleanup|full_cycle|inventory|resource_usage|logs name [--follow] [--tail N]]"
  end
end
