class WorkflowChannel < ApplicationCable::Channel
  def subscribed
    workflow_id = params[:workflow_id]
    workflow = Workflow.find_by(workflow_id: workflow_id)
    return reject unless workflow

    @workflow = workflow
    stream_from "workflow_#{workflow_id}"
    Rails.logger.info("Client subscribed to workflow: #{workflow_id}")

    # Send current state to client
    send_workflow_state
  end

  def unsubscribed
    stop_all_streams
    Rails.logger.info("Client unsubscribed from workflow: #{@workflow&.workflow_id}")
  end

  def request_messages(data)
    # Send recent messages for this workflow
    messages = AgentMessage.by_workflow(@workflow.workflow_id)
      .order(created_at: :desc)
      .limit(100)
      .reverse

    messages.each do |msg|
      transmit({
        type: "message",
        message_id: msg.message_id,
        message_type: msg.message_type,
        timestamp: msg.created_at.iso8601,
        sender: msg.sender_agent_id,
        receiver: msg.receiver_agent_id,
        payload: JSON.parse(msg.payload),
      })
    end
  end

  def request_steps(data)
    # Send current step status
    @workflow.workflow_steps.each do |step|
      transmit({
        type: "step",
        step_id: step.step_id,
        agent_id: step.agent_id,
        status: step.status,
        progress: step.status == "completed" ? 100 : 0,
      })
    end
  end

  private

  def send_workflow_state
    transmit({
      type: "workflow_state",
      workflow_id: @workflow.workflow_id,
      status: @workflow.status,
      name: @workflow.name,
      progress: @workflow.progress_percent,
      total_steps: @workflow.total_steps,
      completed_steps: @workflow.completed_steps,
      pending_steps: @workflow.pending_steps,
      running_steps: @workflow.running_steps,
    })
  end
end
