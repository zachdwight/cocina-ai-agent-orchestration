class ProcessAgentMessagesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting to process agent messages...")

    unless message_broker.connected?
      Rails.logger.warn("RabbitMQ not connected, skipping message processing")
      return
    end

    loop do
      begin
        message = message_broker.get_message("system_messages")
        next if message.nil?

        process_agent_message(message)
      rescue => e
        Rails.logger.error("Error processing messages: #{e.message}")
        sleep(1)  # Avoid tight loop on persistent errors
      end
    end
  rescue => e
    Rails.logger.error("Fatal error in message processing: #{e.message}")
  end

  private

  def message_broker
    Cocina::MessageBroker.instance
  end

  def process_agent_message(message)
    message_id = message[:message_id]
    message_type = message[:message_type]
    correlation_id = message[:correlation_id]
    workflow_id = message[:workflow_id]
    payload = message[:payload] || {}

    Rails.logger.info("Processing message: #{message_type} (#{message_id})")

    # Store in database
    agent_msg = AgentMessage.find_or_create_by(message_id: message_id) do |msg|
      msg.correlation_id = correlation_id
      msg.workflow_id = workflow_id
      msg.message_type = message_type
      msg.sender_agent_id = message[:agent_id]
      msg.payload = message.to_json
      msg.status = "received"
    end

    # Process based on type
    case message_type
    when "task.acknowledgment"
      handle_acknowledgment(message, agent_msg)
    when "task.completion"
      handle_completion(message, agent_msg)
    when "task.progress"
      handle_progress(message, agent_msg)
    when "error.notification"
      handle_error(message, agent_msg)
    when "agent.log_event"
      handle_log_event(message, agent_msg)
    when "agent.heartbeat"
      handle_heartbeat(message, agent_msg)
    else
      Rails.logger.warn("Unknown message type: #{message_type}")
    end

    agent_msg.mark_processed
  rescue => e
    Rails.logger.error("Error processing message: #{e.message}\n#{e.backtrace.join("\n")}")
    agent_msg&.mark_failed(e.message)
  end

  def handle_acknowledgment(message, agent_msg)
    payload = message[:payload]
    task_id = payload[:task_id]
    workflow_id = message[:workflow_id]

    # Extract workflow_id and step_id from task_id (format: "workflow_id:step_id")
    parts = task_id.split(":")
    step_id = parts.last

    step = WorkflowStep.find_by(step_id: step_id)
    if step
      step.update!(status: "running", started_at: Time.current)
      broadcast_step_update(step)
      Rails.logger.info("Task acknowledged: #{task_id}")
    end
  end

  def handle_completion(message, agent_msg)
    payload = message[:payload]
    task_id = payload[:task_id]
    workflow_id = message[:workflow_id]
    result = payload[:result]

    # Extract workflow_id and step_id from task_id
    parts = task_id.split(":")
    step_id = parts.last

    step = WorkflowStep.find_by(step_id: step_id)
    if step
      step.mark_completed(result: result)
      broadcast_step_update(step)
      Rails.logger.info("Task completed: #{task_id}")

      workflow = Workflow.find_by(workflow_id: workflow_id)
      if workflow
        check_and_delegate_next_steps(workflow)
        broadcast_workflow_update(workflow)
      end
    end
  end

  def handle_progress(message, agent_msg)
    payload = message[:payload]
    task_id = payload[:task_id]
    progress = payload[:progress_percent]

    Rails.logger.info("Task progress: #{task_id} - #{progress}%")
    # Could broadcast progress updates here
  end

  def handle_error(message, agent_msg)
    payload = message[:payload]
    task_id = payload[:task_id]
    error_msg = payload[:error_message]

    Rails.logger.error("Task error: #{task_id} - #{error_msg}")

    if task_id
      parts = task_id.split(":")
      step_id = parts.last
      step = WorkflowStep.find_by(step_id: step_id)
      if step
        step.mark_failed(error_msg)
        broadcast_step_update(step)
      end
    end
  end

  def handle_log_event(message, agent_msg)
    payload = message[:payload]
    level = payload[:level]
    log_msg = payload[:message]

    Rails.logger.send(level.to_sym, "Agent log (#{message[:agent_id]}): #{log_msg}")
  end

  def handle_heartbeat(message, agent_msg)
    payload = message[:payload]
    agent_id = message[:agent_id]
    status = payload[:status]

    Rails.logger.debug("Heartbeat from #{agent_id}: #{status}")
    # Could update agent status here
  end

  def check_and_delegate_next_steps(workflow)
    # Find pending steps whose dependencies are met
    ready_steps = workflow.workflow_steps.where(status: "pending").select do |step|
      step.dependencies_met?
    end

    ready_steps.each do |step|
      DelegateTaskJob.perform_later(
        workflow.workflow_id,
        step.step_id,
        step.agent_id,
        step.description,
      )
      Rails.logger.info("Delegating step: #{step.step_id} to #{step.agent_id}")
    end
  end

  def broadcast_step_update(step)
    Turbo::StreamsChannel.broadcast_replace_to(
      "workflow_#{step.workflow_id}",
      target: "step_#{step.step_id}",
      partial: "workflow_steps/step",
      locals: { step: step },
    )
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
