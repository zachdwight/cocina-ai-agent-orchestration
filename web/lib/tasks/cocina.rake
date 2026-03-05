namespace :cocina do
  def orchestrator
    @orchestrator ||= Cocina::Orchestrator.from_records(Agent.all)
  end

  desc "Build all agent Docker images"
  task build: :environment do
    orchestrator.build_images
  end

  desc "Start all agents"
  task start: :environment do
    orchestrator.start_agents
    orchestrator.instance_variable_get(:@agents).each do |a|
      puts orchestrator.agent_status(a.name).inspect
    end
  end

  desc "Stop all agents"
  task stop: :environment do
    orchestrator.stop_agents
  end

  desc "Start a single agent: rake 'cocina:start_agent[chef_agent]'"
  task :start_agent, [:name] => :environment do |_, args|
    orchestrator.orchestrate(:start_agent, args[:name])
  end

  desc "Stop a single agent: rake 'cocina:stop_agent[chef_agent]'"
  task :stop_agent, [:name] => :environment do |_, args|
    orchestrator.stop_agent(args[:name])
  end

  desc "Monitor all agents"
  task monitor: :environment do
    Agent.all.each do |agent|
      s = orchestrator.agent_status(agent.name)
      puts "#{agent.name}: #{s[:status]} #{s[:id]}"
    end
  end

  desc "Full cycle: stop, cleanup, build, start"
  task full_cycle: :environment do
    orchestrator.orchestrate(:full_cycle)
  end

  desc "Cleanup stopped containers"
  task cleanup: :environment do
    orchestrator.cleanup_containers
  end

  desc "Show resource usage"
  task resource_usage: :environment do
    system("docker stats --no-stream " + Agent.pluck(:name).join(" "))
  end

  desc "Stream logs for an agent: rake 'cocina:logs[chef_agent]'"
  task :logs, [:name] => :environment do |_, args|
    orchestrator.stream_logs(args[:name]) { |line| print line }
  end

  desc "Seed DB with the two default agents from cocina.rb"
  task seed_defaults: :environment do
    defaults = [
      {
        name: "chef_agent", description: "Primary Claude agent — plans and coordinates tasks",
        image: "my_ai_agent_chef:latest", command: "python /app/chef_agent.py",
        build_context: "my_ai_agent_chef",
        task: "Plan a 3-course French dinner menu for 4 guests.",
        ports: ["8000:8000"],
        env: { "ANTHROPIC_API_KEY" => ENV.fetch("ANTHROPIC_API_KEY", ""), "AGENT_ID" => "chef_001" }
      },
      {
        name: "sous_agent", description: "Secondary Claude agent — executes specific sub-tasks",
        image: "my_ai_agent_sous:latest", command: "python /app/sous_agent.py",
        build_context: "my_ai_agent_sous",
        task: "Write a detailed recipe for beef bourguignon.",
        ports: [],
        env: { "ANTHROPIC_API_KEY" => ENV.fetch("ANTHROPIC_API_KEY", ""), "AGENT_ID" => "sous_001" }
      }
    ]

    defaults.each do |attrs|
      agent = Agent.find_or_initialize_by(name: attrs[:name])
      agent.assign_attributes(
        description:   attrs[:description],
        image:         attrs[:image],
        command:       attrs[:command],
        build_context: attrs[:build_context],
        task:          attrs[:task]
      )
      agent.ports_list = attrs[:ports]
      agent.save!

      attrs[:env].each do |k, v|
        agent.env_vars.find_or_create_by!(key: k) { |ev| ev.value = v }
      end

      puts "Seeded: #{agent.name}"
    end
  end
end
