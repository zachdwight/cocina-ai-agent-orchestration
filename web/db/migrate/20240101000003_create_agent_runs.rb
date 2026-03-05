class CreateAgentRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_runs do |t|
      t.references :agent,  null: false, foreign_key: true
      t.string  :action,    null: false
      t.string  :status,    null: false, default: "pending"
      t.text    :log_output
      t.string  :container_id
      t.datetime :started_at
      t.datetime :finished_at
      t.integer  :exit_code
      t.timestamps
    end
    add_index :agent_runs, [:agent_id, :created_at]
  end
end
