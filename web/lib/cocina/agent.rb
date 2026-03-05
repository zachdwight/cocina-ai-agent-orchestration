module Cocina
  class Agent
    attr_reader :name, :description, :image, :command,
                :env, :ports, :build, :externals

    def initialize(h)
      @name        = h[:name]
      @description = h[:description]
      @image       = h[:image]
      @command     = h[:command]
      @env         = h[:env] || {}
      @ports       = h[:ports] || []
      @build       = h[:build]
      @externals   = h[:externals]
    end

    def env_flags
      env.flat_map { |k, v| ["-e", "#{k}=#{v}"] }
    end

    def port_flags
      ports.flat_map { |p| ["-p", p] }
    end
  end
end
