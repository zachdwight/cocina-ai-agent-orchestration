# cocina.rb

require 'json' # For potential future configuration loading
require 'open3' # To execute shell commands and capture output/errors

#keep in mind you could pre-build your agents in any location and adjust accordingly
#docker build -t my_ai_agent_chef:latest ./my_ai_agent_chef
#docker build -t my_ai_agent_sous:latest ./my_ai_agent_sous

class DockerAgentOrchestrator
  def initialize(config_file = nil)
    @agents = []
    if config_file
      load_config(config_file)
    else
      # Default example agents if no config file is provided
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
    end
  end

  # Load agent configurations from a JSON file
  def load_config(file_path)
    unless File.exist?(file_path)
      puts "Error: Configuration file '#{file_path}' not found."
      exit 1
    end
    begin
      @agents = JSON.parse(File.read(file_path), symbolize_names: true)
      puts "Loaded agent configurations from #{file_path}"
    rescue JSON::ParserError => e
      puts "Error parsing configuration file: #{e.message}"
      exit 1
    end
  end

  # Run a shell command and capture its output and status
  def run_command(command)
    stdout, stderr, status = Open3.capture3(command)
    unless status.success?
      puts "Command failed: #{command}"
      puts "STDOUT: #{stdout}" unless stdout.empty?
      puts "STDERR: #{stderr}" unless stderr.empty?
    end
    [stdout.strip, stderr.strip, status.success?]
  end

  # Build Docker images (if specified in config or needed)
  # This is a placeholder; you might have a more sophisticated build process
  def build_images
    puts "\n--- Building Docker Images ---"
    @agents.each do |agent|
      # Assuming you have a Dockerfile in a directory named after the agent's image name (without tag)
      image_name_without_tag = agent[:image].split(':').first
      dockerfile_path = "./#{image_name_without_tag}" # Adjust as per your project structure

      if File.exist?(dockerfile_path) && File.directory?(dockerfile_path)
        puts "Attempting to build image: #{agent[:image]} from #{dockerfile_path}"
        command = "docker build -t #{agent[:image]} #{dockerfile_path}"
        _, _, success = run_command(command)
        if success
          puts "Successfully built image: #{agent[:image]}"
        else
          puts "Failed to build image: #{agent[:image]}. Please check your Dockerfile and context."
        end
      else
        puts "Skipping build for #{agent[:image]}. No Dockerfile context found at #{dockerfile_path}"
      end
    end
    puts "--- Image Building Complete ---"
  end


  # Start all defined Docker containers for the agents
  def start_agents
    puts "\n--- Starting AI Agents ---"
    @agents.each do |agent|
      env_vars = agent[:env].map { |k, v| "-e #{k}=\"#{v}\"" }.join(" ")
      ports = agent[:ports].map { |p| "-p #{p}" }.join(" ")
      command = "docker run -d --rm --name #{agent[:name]} #{env_vars} #{ports} #{agent[:image]} #{agent[:command]}"

      puts "Starting container for #{agent[:name]}..."
      stdout, stderr, success = run_command(command)

      if success
        puts "Started #{agent[:name]} (Container ID: #{stdout})"
      else
        puts "Failed to start #{agent[:name]}."
      end
    end
    puts "--- AI Agents Started ---"
  end

  # Monitor the status of the running agents
  def monitor_agents
    puts "\n--- Monitoring AI Agents ---"
    running_agents = []
    @agents.each do |agent|
      stdout, _, success = run_command("docker ps -f name=^/#{agent[:name]}$ --format '{{.ID}}\t{{.Status}}\t{{.Names}}'")
      if success && !stdout.empty?
        id, status, name = stdout.split("\t")
        puts "Agent: #{name}, Status: #{status}, ID: #{id}"
        running_agents << agent[:name]
      else
        puts "Agent: #{agent[:name]} is not running."
      end
    end

    if running_agents.empty?
      puts "No AI agents are currently running."
    end
    puts "--- Monitoring Complete ---"
  end

  # Stop all running agent containers
  def stop_agents
    puts "\n--- Stopping AI Agents ---"
    @agents.each do |agent|
      puts "Stopping container for #{agent[:name]}..."
      stdout, stderr, success = run_command("docker stop #{agent[:name]}")
      if success
        puts "Stopped #{agent[:name]}."
      else
        puts "Failed to stop #{agent[:name]} (might not be running or an error occurred)."
      end
    end
    puts "--- AI Agents Stopped ---"
  end

  # Clean up (remove stopped containers)
  def cleanup_containers
    puts "\n--- Cleaning Up Docker Containers ---"
    @agents.each do |agent|
      puts "Removing container for #{agent[:name]} (if it exists)..."
      # The --rm flag in 'docker run' usually handles this, but this is a failsafe
      stdout, stderr, success = run_command("docker rm #{agent[:name]}")
      if success
        puts "Removed #{agent[:name]}."
      elsif stderr.include?("No such container")
        puts "Container #{agent[:name]} does not exist, no need to remove."
      else
        puts "Failed to remove #{agent[:name]}: #{stderr}"
      end
    end
    puts "--- Cleanup Complete ---"
  end

  def list_agents
    puts "\n--- AI Agent Inventory ---"
    if @agents.empty?
      puts "No agents are registered."
    else
      puts "Total Agents: #{@agents.count}"
      @agents.each_with_index do |agent, index|
        puts "##{index + 1}:"
        puts "  Name: #{agent[:name]}"
        puts "  Description: #{agent[:description] || 'No description provided.'}"
        puts "  Image: #{agent[:image] || 'N/A'}"
        puts "  Build: #{agent[:build] || 'N/A'}"
        puts "  Externals: #{agent[:externals] || 'N/A'}"
      end
    end
    puts "--- Inventory Complete ---"
  end

  # Main orchestration method
  def orchestrate(action)
    case action
    when :start
      build_images # Optional: build images before starting
      start_agents
      monitor_agents
    when :stop
      stop_agents
    when :monitor
      monitor_agents
    when :restart
      stop_agents
      start_agents
      monitor_agents
    when :cleanup
      cleanup_containers
    when :full_cycle
      stop_agents
      cleanup_containers
      build_images
      start_agents
      monitor_agents
    when :inventory
      list_agents
    else
      puts "Unknown action: #{action}. Use :start, :stop, :monitor, :restart, :cleanup, or :full_cycle."
    end
  end
end

# --- Script Execution ---

if __FILE__ == $0
  orchestrator = DockerAgentOrchestrator.new # Or pass a config file: DockerAgentOrchestrator.new("agents_config.json")

  case ARGV[0]
  when "start"
    orchestrator.orchestrate(:start)
  when "stop"
    orchestrator.orchestrate(:stop)
  when "monitor"
    orchestrator.orchestrate(:monitor)
  when "restart"
    orchestrator.orchestrate(:restart)
  when "cleanup"
    orchestrator.orchestrate(:cleanup)
  when "full_cycle"
    orchestrator.orchestrate(:full_cycle)
  when "inventory"
    orchestrator.orchestrate(:inventory)
  else
    puts "Usage: ruby agents_orchestrator.rb [start|stop|monitor|restart|cleanup|full_cycle|inventory]"
    puts "\nExample: ruby agents_orchestrator.rb start"
    puts "  To start all defined AI agent containers."
    puts "\nExample: ruby agents_orchestrator.rb stop"
    puts "  To stop all running AI agent containers."
    puts "\nExample: ruby agents_orchestrator.rb full_cycle"
    puts "  To stop, clean up, build (if needed), and then start all agents."
  end
end

