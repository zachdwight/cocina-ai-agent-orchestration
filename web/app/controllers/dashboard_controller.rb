class DashboardController < ApplicationController
  def index
    @agents = Agent.includes(:env_vars).order(:name)

    orchestrator = Cocina::Orchestrator.from_records(@agents)
    @live_statuses = @agents.each_with_object({}) do |agent, h|
      h[agent.name] = orchestrator.agent_status(agent.name)
    end

    @recent_runs = AgentRun.includes(:agent)
                           .order(created_at: :desc)
                           .limit(10)
  end
end
