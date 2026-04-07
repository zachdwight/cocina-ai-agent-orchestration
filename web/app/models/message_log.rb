class MessageLog < ApplicationRecord
  belongs_to :agent_run, optional: true, inverse_of: :message_logs
  has_one :agent_message, foreign_key: :message_id, primary_key: :message_id

  validates :message_type, :content, :direction, presence: true
  validates :direction, inclusion: { in: %w[sent received] }

  enum direction: { sent: "sent", received: "received" }
  enum message_type: {
    task_delegated: "task.delegated",
    task_acknowledgment: "task.acknowledgment",
    task_progress: "task.progress",
    task_completion: "task.completion",
    workflow_coordination: "workflow.coordination",
    agent_heartbeat: "agent.heartbeat",
    error_notification: "error.notification",
    agent_log_event: "agent.log_event",
  }

  scope :by_agent_run, ->(run_id) { where(agent_run_id: run_id) }
  scope :by_message, ->(msg_id) { where(message_id: msg_id) }
  scope :sent, -> { where(direction: "sent") }
  scope :received, -> { where(direction: "received") }
  scope :by_type, ->(type) { where(message_type: type) }

  def content_data
    @content_data ||= JSON.parse(content) if content.present?
  rescue JSON::ParserError
    nil
  end
end
