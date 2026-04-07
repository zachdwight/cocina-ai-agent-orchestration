class CreateMessageLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :message_logs do |t|
      t.references :agent_run, foreign_key: true, optional: true
      t.string :message_id, null: false, limit: 36
      t.string :direction, null: false, limit: 10
      t.string :message_type, null: false, limit: 50
      t.text :content, null: false

      t.timestamps
    end

    add_index :message_logs, :message_id
    add_index :message_logs, [:agent_run_id, :created_at]
    add_index :message_logs, :message_type

    add_foreign_key :message_logs, :agent_messages, column: :message_id, primary_key: :message_id, on_delete: :cascade
  end
end
