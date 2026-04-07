class WorkflowStep < ApplicationRecord
  belongs_to :workflow, foreign_key: :workflow_id, primary_key: :workflow_id, inverse_of: :workflow_steps
  belongs_to :agent, foreign_key: :agent_id, primary_key: :name, optional: true, inverse_of: :workflow_steps

  validates :step_id, :workflow_id, :agent_id, :status, presence: true
  validates :step_id, uniqueness: true
  validates :status, inclusion: { in: %w[pending assigned running completed failed] }

  enum status: {
    pending: "pending",
    assigned: "assigned",
    running: "running",
    completed: "completed",
    failed: "failed",
  }

  scope :by_status, ->(status) { where(status: status) }
  scope :by_agent, ->(agent_id) { where(agent_id: agent_id) }
  scope :by_workflow, ->(workflow_id) { where(workflow_id: workflow_id) }
  scope :ready_to_run, -> { where(status: "pending") }

  def dependencies
    return [] if depends_on_steps.blank?
    JSON.parse(depends_on_steps)
  end

  def dependencies=(arr)
    self.depends_on_steps = arr.to_json
  end

  def result_data
    @result_data ||= JSON.parse(result) if result.present?
  rescue JSON::ParserError
    nil
  end

  def dependencies_met?
    return true if depends_on_steps.blank?

    dependencies.all? do |dep_id|
      WorkflowStep.find_by(step_id: dep_id)&.completed?
    end
  end

  def mark_running
    update(status: :running, started_at: Time.current)
  end

  def mark_completed(result_data = nil)
    update(
      status: :completed,
      result: result_data.to_json,
      completed_at: Time.current,
    )
    workflow.mark_step_completed
  end

  def mark_failed(error_msg)
    update(
      status: :failed,
      result: { error: error_msg }.to_json,
      completed_at: Time.current,
    )
  end

  def duration
    return nil unless started_at && completed_at
    (completed_at - started_at).round(2)
  end
end
