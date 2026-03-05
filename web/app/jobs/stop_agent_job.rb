class StopAgentJob < ApplicationJob
  queue_as :default

  def perform(agent_id, run_id)
    agent = Agent.find(agent_id)
    run   = AgentRun.find(run_id)
    run.update!(status: "running")

    orchestrator = Cocina::Orchestrator.from_records([agent])
    success = orchestrator.stop_agent(agent.name)

    agent.update!(status: success ? "stopped" : "error", container_id: nil)
    run.update!(
      status:      success ? "completed" : "failed",
      finished_at: Time.current,
      exit_code:   success ? 0 : 1
    )
  rescue => e
    AgentRun.find_by(id: run_id)&.update!(
      status: "failed", finished_at: Time.current, log_output: e.message
    )
    Agent.find_by(id: agent_id)&.update!(status: "error")
    raise
  ensure
    broadcast_status(agent_id)
  end

  private

  def broadcast_status(agent_id)
    agent = Agent.find_by(id: agent_id)
    return unless agent
    Turbo::StreamsChannel.broadcast_replace_to(
      "agent_#{agent.id}",
      target:  "agent_status_#{agent.id}",
      partial: "agents/status_badge",
      locals:  { agent: agent }
    )
  end
end
