import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["output", "streamBtn", "stopBtn"]
  static values  = { agentId: Number }

  connect() {
    this.subscription = null
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  startStream() {
    if (this.subscription) return

    this.outputTarget.textContent = ""

    this.subscription = consumer.subscriptions.create(
      { channel: "AgentLogsChannel", agent_id: this.agentIdValue },
      {
        connected: () => {
          this.subscription.perform("stream")
          if (this.hasStreamBtnTarget) this.streamBtnTarget.disabled = true
          if (this.hasStopBtnTarget)  this.stopBtnTarget.disabled = false
        },
        received: (data) => {
          if (data.line !== undefined) {
            this.outputTarget.textContent += data.line + "\n"
            this.outputTarget.scrollTop = this.outputTarget.scrollHeight
          }
          if (data.error) {
            this.outputTarget.textContent += `[Error] ${data.error}\n`
          }
        }
      }
    )
  }

  stopStream() {
    this.subscription?.perform("stop_stream")
    this.subscription?.unsubscribe()
    this.subscription = null
    if (this.hasStreamBtnTarget) this.streamBtnTarget.disabled = false
    if (this.hasStopBtnTarget)  this.stopBtnTarget.disabled = true
  }
}
