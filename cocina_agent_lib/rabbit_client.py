"""RabbitMQ client wrapper for Cocina agents."""

import json
import pika
import logging

logger = logging.getLogger(__name__)


class RabbitClient:
    """Wrapper around pika for RabbitMQ communication."""

    def __init__(self, host="localhost", port=5672, username="guest", password="guest", vhost="/"):
        """Initialize RabbitMQ client parameters."""
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.vhost = vhost

        self.connection = None
        self.channel = None
        self._connected = False

    def connect(self):
        """Establish connection to RabbitMQ."""
        try:
            credentials = pika.PlainCredentials(self.username, self.password)
            parameters = pika.ConnectionParameters(
                host=self.host,
                port=self.port,
                virtual_host=self.vhost,
                credentials=credentials,
                heartbeat=600,
                blocked_connection_timeout=300,
            )

            self.connection = pika.BlockingConnection(parameters)
            self.channel = self.connection.channel()
            self._connected = True

            logger.info(f"Connected to RabbitMQ at {self.host}:{self.port}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to RabbitMQ: {str(e)}")
            self._connected = False
            return False

    @property
    def connected(self):
        """Check if connected to RabbitMQ."""
        return self._connected and self.connection and not self.connection.is_closed

    def declare_exchange(self, exchange_name, exchange_type="direct", durable=True):
        """Declare an exchange."""
        if not self.connected:
            logger.error("Not connected to RabbitMQ")
            return None

        try:
            self.channel.exchange_declare(
                exchange=exchange_name,
                exchange_type=exchange_type,
                durable=durable,
                auto_delete=False,
            )
            logger.debug(f"Declared {exchange_type} exchange: {exchange_name}")
            return self.channel.exchange(exchange_name)
        except Exception as e:
            logger.error(f"Failed to declare exchange {exchange_name}: {str(e)}")
            return None

    def declare_queue(self, queue_name, durable=True, auto_delete=False):
        """Declare a queue."""
        if not self.connected:
            logger.error("Not connected to RabbitMQ")
            return None

        try:
            self.channel.queue_declare(
                queue=queue_name,
                durable=durable,
                auto_delete=auto_delete,
                exclusive=False,
            )
            logger.debug(f"Declared queue: {queue_name}")
            return self.channel.queue(queue_name)
        except Exception as e:
            logger.error(f"Failed to declare queue {queue_name}: {str(e)}")
            return None

    def bind_queue(self, queue_name, exchange_name, routing_key):
        """Bind queue to exchange."""
        if not self.connected:
            logger.error("Not connected to RabbitMQ")
            return False

        try:
            self.channel.queue_bind(
                exchange=exchange_name,
                queue=queue_name,
                routing_key=routing_key,
            )
            logger.debug(f"Bound queue {queue_name} to {exchange_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to bind queue: {str(e)}")
            return False

    def publish(self, message, routing_key="", exchange="", persistent=True):
        """Publish a message."""
        if not self.connected:
            logger.error("Not connected to RabbitMQ")
            return False

        try:
            message_str = json.dumps(message) if isinstance(message, dict) else message
            properties = pika.BasicProperties(
                delivery_mode=2 if persistent else 1,
                content_type="application/json",
            )

            self.channel.basic_publish(
                exchange=exchange,
                routing_key=routing_key,
                body=message_str,
                properties=properties,
            )
            logger.debug(f"Published message to {routing_key}")
            return True
        except Exception as e:
            logger.error(f"Failed to publish message: {str(e)}")
            return False

    def consume(self, queue_name, callback, prefetch=1):
        """Start consuming messages from a queue."""
        if not self.connected:
            logger.error("Not connected to RabbitMQ")
            return False

        try:
            self.channel.basic_qos(prefetch_count=prefetch)

            def message_callback(ch, method, properties, body):
                try:
                    message = json.loads(body.decode("utf-8"))
                    callback(message, method)
                    ch.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    logger.error(f"Error processing message: {str(e)}")
                    ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

            self.channel.basic_consume(
                queue=queue_name,
                on_message_callback=message_callback,
                auto_ack=False,
            )

            logger.info(f"Starting to consume messages from {queue_name}")
            self.channel.start_consuming()
            return True
        except Exception as e:
            logger.error(f"Error consuming messages: {str(e)}")
            return False

    def get_message(self, queue_name):
        """Get a single message from queue (non-blocking)."""
        if not self.connected:
            logger.error("Not connected to RabbitMQ")
            return None

        try:
            method, properties, body = self.channel.basic_get(queue=queue_name, auto_ack=False)
            if method:
                message = json.loads(body.decode("utf-8"))
                self.channel.basic_ack(delivery_tag=method.delivery_tag)
                return message
            return None
        except Exception as e:
            logger.error(f"Error getting message: {str(e)}")
            return None

    def ack(self, delivery_tag):
        """Acknowledge a message."""
        try:
            self.channel.basic_ack(delivery_tag=delivery_tag)
        except Exception as e:
            logger.error(f"Error acknowledging message: {str(e)}")

    def nack(self, delivery_tag, requeue=True):
        """Reject a message."""
        try:
            self.channel.basic_nack(delivery_tag=delivery_tag, requeue=requeue)
        except Exception as e:
            logger.error(f"Error nacking message: {str(e)}")

    def purge_queue(self, queue_name):
        """Purge all messages from queue."""
        if not self.connected:
            logger.error("Not connected to RabbitMQ")
            return False

        try:
            self.channel.queue_purge(queue=queue_name)
            logger.info(f"Purged queue: {queue_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to purge queue: {str(e)}")
            return False

    def delete_queue(self, queue_name):
        """Delete a queue."""
        if not self.connected:
            logger.error("Not connected to RabbitMQ")
            return False

        try:
            self.channel.queue_delete(queue=queue_name)
            logger.info(f"Deleted queue: {queue_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete queue: {str(e)}")
            return False

    def close(self):
        """Close connection to RabbitMQ."""
        try:
            if self.connection and not self.connection.is_closed:
                self.connection.close()
            self._connected = False
            logger.info("Disconnected from RabbitMQ")
        except Exception as e:
            logger.error(f"Error closing connection: {str(e)}")
