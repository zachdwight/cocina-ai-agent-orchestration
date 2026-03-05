class BuildImageJob < ApplicationJob
  queue_as :default

  def perform(agent_id, run_id)
    agent = Agent.find(agent_id)
    run   = AgentRun.find(run_id)
    run.update!(status: "running")

    orchestrator = Cocina::Orchestrator.from_records([agent])
    orchestrator.build_images

    run.update!(status: "completed", finished_at: Time.current, exit_code: 0)
  rescue => e
    AgentRun.find_by(id: run_id)&.update!(
      status: "failed", finished_at: Time.current, log_output: e.message
    )
    raise
  end
end
