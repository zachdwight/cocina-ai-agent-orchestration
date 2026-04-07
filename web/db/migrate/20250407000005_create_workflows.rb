class CreateWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :workflows do |t|
      t.string :workflow_id, null: false, limit: 36
      t.string :name, limit: 255
      t.text :description
      t.string :status, null: false, default: "pending", limit: 20
      t.string :initiated_by, limit: 100
      t.integer :total_steps
      t.integer :completed_steps, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end

    add_index :workflows, :workflow_id, unique: true
    add_index :workflows, :status
    add_index :workflows, :created_at
  end
end
