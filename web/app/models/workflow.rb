class Workflow < ApplicationRecord
  has_many :workflow_steps, foreign_key: :workflow_id, primary_key: :workflow_id, dependent: :destroy
  has_many :agent_messages, foreign_key: :workflow_id, primary_key: :workflow_id, dependent: :destroy

  validates :workflow_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[pending running completed failed] }

  enum status: {
    pending: "pending",
    running: "running",
    completed: "completed",
    failed: "failed",
  }

  scope :active, -> { where(status: %w[pending running]) }
  scope :finished, -> { where(status: %w[completed failed]) }
  scope :by_initiator, ->(initiator) { where(initiated_by: initiator) }

  def progress_percent
    return 0 if total_steps.blank? || total_steps.zero?
    ((completed_steps || 0).to_f / total_steps * 100).round
  end

  def pending_steps
    workflow_steps.where(status: "pending").count
  end

  def running_steps
    workflow_steps.where(status: %w[assigned running]).count
  end

  def mark_step_completed
    increment!(:completed_steps)
    check_completion
  end

  def mark_failed(error_msg)
    update(status: :failed, error_message: error_msg, completed_at: Time.current)
  end

  def all_steps_complete?
    pending_steps.zero? && workflow_steps.where(status: "pending").count.zero?
  end

  private

  def check_completion
    if completed_steps >= (total_steps || 0)
      update(status: :completed, completed_at: Time.current)
    end
  end
end
