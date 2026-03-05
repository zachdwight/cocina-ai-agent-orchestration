class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents do |t|
      t.string  :name,          null: false
      t.string  :description
      t.string  :image,         null: false
      t.string  :command,       null: false
      t.string  :build_context
      t.string  :externals
      t.text    :ports
      t.text    :task
      t.string  :status,        null: false, default: "stopped"
      t.string  :container_id
      t.timestamps
    end
    add_index :agents, :name, unique: true
  end
end
