class Agent < ApplicationRecord
  has_many :agent_runs, dependent: :destroy
  has_many :env_vars,   dependent: :destroy, autosave: true
  has_many :sent_messages, class_name: 'AgentMessage', foreign_key: :sender_agent_id, dependent: :nullify
  has_many :received_messages, class_name: 'AgentMessage', foreign_key: :receiver_agent_id, dependent: :nullify
  has_many :workflow_steps, foreign_key: :agent_id, dependent: :nullify

  accepts_nested_attributes_for :env_vars,
    allow_destroy: true,
    reject_if: proc { |attrs| attrs[:key].blank? }

  validates :name,    presence: true, uniqueness: true,
                      format: { with: /\A[a-z0-9_\-]+\z/,
                                message: "only lowercase letters, numbers, hyphens, underscores" }
  validates :image,   presence: true
  validates :command, presence: true
  validates :status,  inclusion: { in: %w[stopped running error pending] }
  validates :mode,    inclusion: { in: %w[env rabbitmq hybrid] }, allow_nil: true
  validates :rabbitmq_queue_name, format: { with: /\A[a-z0-9_\-\.]+\z/ }, allow_nil: true

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
