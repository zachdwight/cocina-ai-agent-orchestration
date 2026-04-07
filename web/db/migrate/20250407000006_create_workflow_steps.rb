class CreateWorkflowSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_steps do |t|
      t.string :workflow_id, null: false, limit: 36
      t.string :step_id, null: false, limit: 36
      t.string :task_id, limit: 36
      t.string :agent_id, null: false, limit: 100
      t.text :description
      t.string :status, null: false, default: "pending", limit: 20
      t.text :depends_on_steps
      t.text :result
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :workflow_steps, :step_id, unique: true
    add_index :workflow_steps, :workflow_id
    add_index :workflow_steps, :agent_id
    add_index :workflow_steps, :status
    add_index :workflow_steps, [:workflow_id, :status]

    add_foreign_key :workflow_steps, :workflows, column: :workflow_id, primary_key: :workflow_id, on_delete: :cascade
    add_foreign_key :workflow_steps, :agents, column: :agent_id, primary_key: :name, on_delete: :restrict
  end
end
