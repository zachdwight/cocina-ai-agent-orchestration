class CreateAgentMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_messages do |t|
      t.string :message_id, null: false, limit: 36
      t.string :correlation_id, null: false, limit: 36
      t.string :workflow_id, limit: 36
      t.string :message_type, null: false, limit: 50
      t.string :sender_agent_id, limit: 100
      t.string :receiver_agent_id, limit: 100
      t.text :payload, null: false
      t.string :status, null: false, default: "received", limit: 20
      t.datetime :processed_at
      t.text :error_message

      t.timestamps
    end

    add_index :agent_messages, :message_id, unique: true
    add_index :agent_messages, :correlation_id
    add_index :agent_messages, :workflow_id
    add_index :agent_messages, :message_type
    add_index :agent_messages, :sender_agent_id
    add_index :agent_messages, :receiver_agent_id

    add_foreign_key :agent_messages, :agents, column: :sender_agent_id, primary_key: :name, on_delete: :nullify
    add_foreign_key :agent_messages, :agents, column: :receiver_agent_id, primary_key: :name, on_delete: :nullify
  end
end
