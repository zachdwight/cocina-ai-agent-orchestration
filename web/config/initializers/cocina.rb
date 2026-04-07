# Eagerly load Cocina domain classes so they are available
# in controllers, jobs, and channels without manual requires.
require Rails.root.join("lib/cocina/agent")
require Rails.root.join("lib/cocina/orchestrator")
require Rails.root.join("lib/cocina/agent_adapter")
require Rails.root.join("lib/cocina/message_broker")

# Initialize RabbitMQ connection if configured
if ENV["RABBITMQ_HOST"].present?
  begin
    broker = Cocina::MessageBroker.instance
    broker.connect(
      ENV["RABBITMQ_HOST"] || "localhost",
      ENV["RABBITMQ_PORT"]&.to_i || 5672,
      ENV["RABBITMQ_USER"] || "guest",
      ENV["RABBITMQ_PASS"] || "guest",
    )
    Rails.logger.info("RabbitMQ MessageBroker initialized")
  rescue => e
    Rails.logger.warn("Failed to initialize RabbitMQ: #{e.message}")
  end
end
