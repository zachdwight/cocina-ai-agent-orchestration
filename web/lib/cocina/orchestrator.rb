require "open3"
require "shellwords"
require "json"

module Cocina
  class Orchestrator
    def initialize(agents = [])
      @agents = agents
    end

    def self.from_records(agent_records)
      agents = Array(agent_records).map(&:to_cocina_agent)
      new(agents)
    end

    # Run a docker command. Yields each output line if a block is given
    # (used by ActionCable for streaming). Returns [stdout, stderr, success].
    def run_command(cmd_array, &block)
      if block
        Open3.popen2e(*cmd_array) do |_stdin, stdout_err, wait_thr|
          stdout_err.each_line { |line| block.call(line) }
          [nil, nil, wait_thr.value.success?]
        end
      else
        stdout, stderr, status = Open3.capture3(*cmd_array)
        unless status.success?
          logger.warn("Command failed: #{cmd_array.shelljoin}")
          logger.warn("STDOUT: #{stdout}") unless stdout.empty?
          logger.warn("STDERR: #{stderr}") unless stderr.empty?
        end
        [stdout.strip, stderr.strip, status.success?]
      end
    end

    def wait_for_healthy(agent, timeout: 25)
      start_time = Time.now
      loop do
        inspect_cmd = ["docker", "inspect", "--format={{json .State.Health}}", agent.name]
        stdout, _, _ = run_command(inspect_cmd)
        if stdout.nil? || stdout.empty? || stdout == "null"
          logger.info("No HEALTHCHECK for #{agent.name}; skipping wait.")
          return true
        end

        inspect_cmd = ["docker", "inspect", "--format={{.State.Health.Status}}", agent.name]
        health, _, _ = run_command(inspect_cmd)
        return true if health == "healthy"
        break if Time.now - start_time > timeout
        sleep 1
      end
      false
    end

    def build_images
      @agents.each do |agent|
        dir = agent.build || agent.image.split(":").first
        next unless File.directory?(dir)

        logger.info("Building #{agent.image} from #{dir}")
        _, _, success = run_command(["docker", "build", "-t", agent.image, dir])
        logger.info(success ? "Built #{agent.image}" : "Failed to build #{agent.image}")
      end
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

      stdout, _, success = run_command(args)
      if success
        logger.info("Started #{agent.name} (#{stdout})")
        wait_for_healthy(agent)
      else
        logger.warn("Failed to start #{agent.name}")
      end
      success
    end

    def start_agents
      @agents.each { |a| start_single(a) }
    end

    def stop_agent(name)
      _, _, success = run_command(["docker", "stop", name])
      logger.info(success ? "Stopped #{name}" : "Could not stop #{name}")
      success
    end

    def stop_agents
      @agents.each { |a| stop_agent(a.name) }
    end

    def cleanup_containers
      @agents.each do |agent|
        _, _, success = run_command(["docker", "rm", agent.name])
        logger.info(success ? "Removed #{agent.name}" : "Could not remove #{agent.name}")
      end
    end

    # Returns { running:, id:, status: } for a named container.
    def agent_status(name)
      cmd = [
        "docker", "ps",
        "-f", "name=^/#{name}$",
        "--format", "{{.ID}}\t{{.Status}}"
      ]
      stdout, _, _ = run_command(cmd)
      if stdout.empty?
        { running: false, id: nil, status: "stopped" }
      else
        id, status = stdout.split("\t")
        { running: true, id: id&.strip, status: status&.strip }
      end
    end

    # Streams docker logs --follow, yielding each line to the block.
    def stream_logs(name, tail: 50, &block)
      run_command(["docker", "logs", "--follow", "--tail", tail.to_s, name], &block)
    end

    def orchestrate(action, agent_name = nil)
      case action
      when :start      then build_images; start_agents
      when :stop       then stop_agents
      when :start_agent then start_single(@agents.find { |a| a.name == agent_name })
      when :stop_agent  then stop_agent(agent_name)
      when :full_cycle  then stop_agents; cleanup_containers; build_images; start_agents
      when :cleanup     then cleanup_containers
      end
    end

    private

    def logger
      defined?(Rails) ? Rails.logger : Logger.new($stdout)
    end
  end
end
