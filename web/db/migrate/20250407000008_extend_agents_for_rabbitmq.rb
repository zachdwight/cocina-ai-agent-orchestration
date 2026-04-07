class ExtendAgentsForRabbitmq < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :rabbitmq_queue_name, :string, limit: 100
    add_column :agents, :supports_rabbitmq, :boolean, default: true
    add_column :agents, :mode, :string, default: "hybrid", limit: 20

    add_column :agent_runs, :workflow_id, :string, limit: 36
    add_column :agent_runs, :correlation_id, :string, limit: 36

    add_index :agent_runs, :workflow_id
    add_index :agent_runs, :correlation_id
  end
end
