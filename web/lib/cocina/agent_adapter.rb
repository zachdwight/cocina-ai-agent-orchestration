module Cocina
  module AgentAdapter
    def self.from_record(record)
      env = record.env_hash

      # Inject the TASK env var if set on the record and not already in env_vars
      env["TASK"] = record.task if record.task.present? && env["TASK"].blank?

      Cocina::Agent.new(
        name:        record.name,
        description: record.description,
        image:       record.image,
        command:     record.command,
        env:         env,
        ports:       record.ports_list,
        build:       record.build_context,
        externals:   record.externals
      )
    end
  end
end
