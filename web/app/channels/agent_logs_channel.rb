class AgentLogsChannel < ApplicationCable::Channel
  def subscribed
    agent = Agent.find_by(id: params[:agent_id])
    return reject unless agent

    @agent = agent
    stream_from "agent_logs_#{agent.id}"
  end

  def unsubscribed
    stop_all_streams
    @log_thread&.kill
    @log_thread = nil
  end

  # Client calls channel.perform("stream") to start tailing logs.
  def stream
    return unless @agent

    @log_thread&.kill # kill any previous stream

    @log_thread = Thread.new do
      orchestrator = Cocina::Orchestrator.new
      orchestrator.stream_logs(@agent.name) do |line|
        ActionCable.server.broadcast(
          "agent_logs_#{@agent.id}",
          { line: line.chomp, timestamp: Time.current.iso8601 }
        )
      end
    rescue => e
      ActionCable.server.broadcast(
        "agent_logs_#{@agent.id}",
        { error: e.message }
      )
    end
  end

  def stop_stream
    @log_thread&.kill
    @log_thread = nil
  end
end
