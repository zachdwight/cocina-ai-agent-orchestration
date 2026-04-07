module Cocina
  class MessageBroker
    include Singleton

    def initialize
      @client = nil
      @channel = nil
      @connection_params = {}
    end

    def connect(host, port, username, password)
      require 'bunny'
      @connection_params = {
        host: host,
        port: port,
        username: username,
        password: password,
        vhost: '/'
      }

      @client = Bunny.new(@connection_params)
      @client.start
      @channel = @client.create_channel

      Rails.logger.info("Connected to RabbitMQ at #{host}:#{port}")
    rescue => e
      Rails.logger.error("Failed to connect to RabbitMQ: #{e.message}")
      raise
    end

    def connected?
      @client&.connected?
    end

    def declare_queue(name, durable: true, auto_delete: false)
      return nil unless @channel

      @channel.queue(name, durable: durable, auto_delete: auto_delete)
    end

    def declare_exchange(name, type: :direct, durable: true)
      return nil unless @channel

      @channel.exchange(name, type: type, durable: durable)
    end

    def bind_queue(queue_name, exchange_name, routing_key)
      return nil unless @channel

      queue = @channel.queue(queue_name)
      exchange = @channel.exchange(exchange_name)
      queue.bind(exchange, routing_key: routing_key)
    end

    def publish(queue_name, message, options = {})
      return nil unless @channel

      queue = declare_queue(queue_name)
      @channel.default_exchange.publish(
        message.is_a?(String) ? message : message.to_json,
        routing_key: queue.name,
        persistent: options[:persistent] != false
      )

      Rails.logger.debug("Published message to #{queue_name}: #{message.inspect}")
    rescue => e
      Rails.logger.error("Failed to publish message: #{e.message}")
      raise
    end

    def consume(queue_name, prefetch: 1)
      return nil unless @channel

      @channel.prefetch(prefetch)
      queue = declare_queue(queue_name)

      queue.subscribe(manual_ack: true, block: false) do |delivery_info, properties, body|
        yield(JSON.parse(body, symbolize_names: true), delivery_info) if block_given?
        @channel.ack(delivery_info.delivery_tag)
      rescue => e
        Rails.logger.error("Error processing message: #{e.message}")
        @channel.nack(delivery_info.delivery_tag, true)
      end
    end

    def get_message(queue_name)
      return nil unless @channel

      queue = declare_queue(queue_name)
      delivery_info, properties, body = queue.get

      return nil unless body

      JSON.parse(body, symbolize_names: true)
    rescue => e
      Rails.logger.error("Error getting message: #{e.message}")
      nil
    end

    def purge_queue(queue_name)
      return nil unless @channel

      queue = @channel.queue(queue_name)
      queue.purge
    end

    def delete_queue(queue_name)
      return nil unless @channel

      queue = @channel.queue(queue_name)
      queue.delete
    end

    def close
      @channel&.close if @channel
      @client&.close if @client
      Rails.logger.info("Disconnected from RabbitMQ")
    rescue => e
      Rails.logger.error("Error closing RabbitMQ connection: #{e.message}")
    end
  end
end
