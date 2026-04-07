module WorkflowsHelper
  def status_badge_class(status)
    case status
    when "pending"
      "bg-gray-100 text-gray-800"
    when "running"
      "bg-yellow-100 text-yellow-800"
    when "completed"
      "bg-green-100 text-green-800"
    when "failed"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def step_border_class(status)
    case status
    when "pending"
      "border-gray-400"
    when "assigned", "running"
      "border-yellow-400"
    when "completed"
      "border-green-400"
    when "failed"
      "border-red-400"
    else
      "border-gray-400"
    end
  end

  def step_status_badge(status)
    case status
    when "pending"
      "bg-gray-200 text-gray-800"
    when "assigned"
      "bg-blue-200 text-blue-800"
    when "running"
      "bg-yellow-200 text-yellow-800"
    when "completed"
      "bg-green-200 text-green-800"
    when "failed"
      "bg-red-200 text-red-800"
    else
      "bg-gray-200 text-gray-800"
    end
  end

  def message_type_border(msg_type)
    case msg_type
    when "task.delegated"
      "border-blue-400"
    when "task.acknowledgment"
      "border-green-400"
    when "task.completion"
      "border-cyan-400"
    when "task.progress"
      "border-amber-400"
    when "error.notification"
      "border-red-400"
    when "agent.log_event"
      "border-purple-400"
    when "agent.heartbeat"
      "border-indigo-400"
    else
      "border-gray-400"
    end
  end

  def message_type_badge(msg_type)
    case msg_type
    when "task.delegated"
      "bg-blue-200 text-blue-800"
    when "task.acknowledgment"
      "bg-green-200 text-green-800"
    when "task.completion"
      "bg-cyan-200 text-cyan-800"
    when "task.progress"
      "bg-amber-200 text-amber-800"
    when "error.notification"
      "bg-red-200 text-red-800"
    when "agent.log_event"
      "bg-purple-200 text-purple-800"
    when "agent.heartbeat"
      "bg-indigo-200 text-indigo-800"
    else
      "bg-gray-200 text-gray-800"
    end
  end

  def workflow_messages_path(workflow_id)
    "/workflows/#{workflow_id}/messages"
  end

  def start_workflow_path(workflow_id)
    "/workflows/#{workflow_id}/start"
  end
end
