class AgentMessage < ApplicationRecord
  belongs_to :sender_agent, class_name: "Agent", foreign_key: :sender_agent_id, primary_key: :name, optional: true
  belongs_to :receiver_agent, class_name: "Agent", foreign_key: :receiver_agent_id, primary_key: :name, optional: true
  has_many :message_logs, foreign_key: :message_id, primary_key: :message_id, dependent: :delete_all

  validates :message_id, :message_type, :payload, presence: true
  validates :message_id, uniqueness: true
  validates :status, inclusion: { in: %w[received processed failed] }

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

  scope :unprocessed, -> { where(status: "received") }
  scope :by_correlation, ->(id) { where(correlation_id: id) }
  scope :by_workflow, ->(id) { where(workflow_id: id) }
  scope :by_sender, ->(agent_id) { where(sender_agent_id: agent_id) }
  scope :by_receiver, ->(agent_id) { where(receiver_agent_id: agent_id) }

  # Parse payload JSON
  def payload_data
    @payload_data ||= JSON.parse(payload) if payload.present?
  end

  def mark_processed
    update(status: "processed", processed_at: Time.current)
  end

  def mark_failed(error_msg)
    update(status: "failed", error_message: error_msg, processed_at: Time.current)
  end
end
