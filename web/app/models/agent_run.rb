class AgentRun < ApplicationRecord
  belongs_to :agent

  ACTIONS  = %w[start stop full_cycle build].freeze
  STATUSES = %w[pending running completed failed].freeze

  validates :action, inclusion: { in: ACTIONS }
  validates :status, inclusion: { in: STATUSES }

  def duration
    return nil unless started_at && finished_at
    (finished_at - started_at).round(1)
  end

  def completed?
    status.in?(%w[completed failed])
  end

  def status_color
    case status
    when "completed" then "green"
    when "running"   then "yellow"
    when "failed"    then "red"
    else                  "gray"
    end
  end
end
