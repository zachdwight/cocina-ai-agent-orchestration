class DelegateTaskJob < ApplicationJob
  queue_as :default

  def perform(workflow_id, step_id, agent_name, task_description)
    workflow = Workflow.find_by(workflow_id: workflow_id)
    step = WorkflowStep.find_by(step_id: step_id)
    agent = Agent.find_by(name: agent_name)

    unless workflow && step && agent
      Rails.logger.error("Missing workflow, step, or agent for delegation")
      return
    end

    correlation_id = SecureRandom.uuid
    task_id = "#{workflow_id}:#{step_id}"

    # Create the message
    message = {
      message_type: "task.delegated",
      message_id: SecureRandom.uuid,
      correlation_id: correlation_id,
      workflow_id: workflow_id,
      agent_id: "system",
      timestamp: Time.current.iso8601,
      payload: {
        task_id: task_id,
        task_description: task_description,
        dependencies: dependencies_for_step(step),
        priority: "normal",
        timeout_seconds: 3600,
      },
    }

    # Publish to RabbitMQ if available
    if message_broker.connected?
      message_broker.publish(agent.rabbitmq_queue_name || agent_name, message)
      Rails.logger.info("Published task delegation to #{agent_name}: #{task_id}")
    else
      Rails.logger.warn("RabbitMQ not connected, skipping message publish")
    end

    # Log in database
    AgentMessage.create!(
      message_id: message[:message_id],
      correlation_id: correlation_id,
      workflow_id: workflow_id,
      message_type: "task_delegated",
      receiver_agent_id: agent_name,
      payload: message.to_json,
      status: "received",
    )

    # Update step status
    step.update!(status: "assigned")

    # Broadcast update to connected clients
    broadcast_workflow_update(workflow)
  end

  private

  def message_broker
    Cocina::MessageBroker.instance
  end

  def dependencies_for_step(step)
    return [] if step.depends_on_steps.blank?
    JSON.parse(step.depends_on_steps)
  rescue JSON::ParserError
    []
  end

  def broadcast_workflow_update(workflow)
    Turbo::StreamsChannel.broadcast_replace_to(
      "workflow_#{workflow.workflow_id}",
      target: "workflow_progress",
      partial: "workflows/progress",
      locals: { workflow: workflow },
    )
  end
end
