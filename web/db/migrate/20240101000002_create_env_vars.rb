class CreateEnvVars < ActiveRecord::Migration[8.0]
  def change
    create_table :env_vars do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :key,   null: false
      t.string :value, null: false, default: ""
      t.timestamps
    end
  end
end
