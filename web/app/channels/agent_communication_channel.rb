class AgentCommunicationChannel < ApplicationCable::Channel
  def subscribed
    agent = Agent.find_by(id: params[:agent_id])
    return reject unless agent

    @agent = agent
    stream_from "agent_communication_#{agent.id}"
    Rails.logger.info("Client subscribed to agent communication: #{agent.id}")
  end

  def unsubscribed
    stop_all_streams
    Rails.logger.info("Client unsubscribed from agent communication")
  end

  def request_messages(data)
    # Send recent messages to client
    messages = AgentMessage.where(
      "sender_agent_id = ? OR receiver_agent_id = ?",
      @agent.name,
      @agent.name,
    ).order(created_at: :desc).limit(50).reverse

    messages.each do |msg|
      transmit({
        type: "message",
        message_id: msg.message_id,
        message_type: msg.message_type,
        correlation_id: msg.correlation_id,
        timestamp: msg.created_at.iso8601,
        payload: JSON.parse(msg.payload),
      })
    end
  end
end
