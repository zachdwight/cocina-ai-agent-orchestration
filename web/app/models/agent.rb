class Agent < ApplicationRecord
  has_many :agent_runs, dependent: :destroy
  has_many :env_vars,   dependent: :destroy, autosave: true

  accepts_nested_attributes_for :env_vars,
    allow_destroy: true,
    reject_if: proc { |attrs| attrs[:key].blank? }

  validates :name,    presence: true, uniqueness: true,
                      format: { with: /\A[a-z0-9_\-]+\z/,
                                message: "only lowercase letters, numbers, hyphens, underscores" }
  validates :image,   presence: true
  validates :command, presence: true
  validates :status,  inclusion: { in: %w[stopped running error pending] }

  def ports_list
    JSON.parse(ports || "[]")
  rescue JSON::ParserError
    []
  end

  def ports_list=(arr)
    self.ports = arr.compact_blank.to_json
  end

  def running?
    status == "running"
  end

  def pending?
    status == "pending"
  end

  def env_hash
    env_vars.each_with_object({}) { |ev, h| h[ev.key] = ev.value }
  end

  def to_cocina_agent
    Cocina::AgentAdapter.from_record(self)
  end

  def status_color
    case status
    when "running" then "green"
    when "pending" then "yellow"
    when "error"   then "red"
    else                "gray"
    end
  end
end
