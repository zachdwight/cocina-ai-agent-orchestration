import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    workflowId: String
  }

  connect() {
    console.log("Workflow controller connected for:", this.workflowIdValue)
    this.subscribeToWorkflow()
  }

  disconnect() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  subscribeToWorkflow() {
    this.channel = App.cable.subscriptions.create(
      { channel: "WorkflowChannel", workflow_id: this.workflowIdValue },
      {
        received: (data) => this.handleUpdate(data),
        connected: () => this.onConnected(),
        disconnected: () => this.onDisconnected(),
        rejected: () => this.onRejected()
      }
    )
  }

  handleUpdate(data) {
    console.log("Received workflow update:", data)

    if (data.type === "step") {
      this.updateStep(data)
    } else if (data.type === "workflow_state") {
      this.updateWorkflowState(data)
    } else if (data.type === "message") {
      this.addMessage(data)
    }
  }

  updateStep(data) {
    const stepEl = document.getElementById(`step_${data.step_id}`)
    if (stepEl) {
      // Update status badge
      const badge = stepEl.querySelector('[class*="bg-"]')
      if (badge) {
        badge.className = this.getStatusBadgeClass(data.status)
        badge.textContent = data.status.toUpperCase()
      }

      // Update border color
      stepEl.className = `border-l-4 p-4 bg-gray-50 ${this.getStepBorderClass(data.status)}`
    }
  }

  updateWorkflowState(data) {
    // Update progress bar
    const progressBar = document.querySelector("#workflow_progress > div")
    if (progressBar) {
      progressBar.style.width = data.progress + "%"
    }

    // Update counters
    const statElements = {
      completed: document.querySelector('[data-stat="completed"]'),
      running: document.querySelector('[data-stat="running"]'),
      pending: document.querySelector('[data-stat="pending"]'),
      total: document.querySelector('[data-stat="total"]')
    }

    if (statElements.completed) statElements.completed.textContent = data.completed_steps
    if (statElements.running) statElements.running.textContent = data.running_steps
    if (statElements.pending) statElements.pending.textContent = data.pending_steps
    if (statElements.total) statElements.total.textContent = data.total_steps
  }

  addMessage(data) {
    const messagesContainer = document.getElementById("workflow_messages")
    if (!messagesContainer) return

    const messageEl = document.createElement("div")
    messageEl.className = `p-3 bg-gray-50 rounded text-sm border-l-4 ${this.getMessageBorderClass(data.message_type)}`
    messageEl.innerHTML = `
      <div class="flex justify-between items-start">
        <div>
          <strong>${data.message_type.toUpperCase()}</strong>
          <br>
          <span class="text-xs text-gray-600">
            ${data.sender ? `From: <strong>${data.sender}</strong>` : ''}
            ${data.receiver ? `To: <strong>${data.receiver}</strong>` : ''}
          </span>
        </div>
        <span class="text-xs text-gray-600">${new Date().toLocaleTimeString()}</span>
      </div>
    `

    messagesContainer.insertBefore(messageEl, messagesContainer.firstChild)

    // Keep only last 50 messages
    const messages = messagesContainer.querySelectorAll(".p-3")
    if (messages.length > 50) {
      messages[messages.length - 1].remove()
    }
  }

  onConnected() {
    console.log("Connected to workflow channel")
  }

  onDisconnected() {
    console.log("Disconnected from workflow channel")
  }

  onRejected() {
    console.log("Rejected workflow channel subscription")
  }

  getStatusBadgeClass(status) {
    const classes = {
      pending: "bg-gray-200 text-gray-800",
      assigned: "bg-blue-200 text-blue-800",
      running: "bg-yellow-200 text-yellow-800",
      completed: "bg-green-200 text-green-800",
      failed: "bg-red-200 text-red-800"
    }
    return classes[status] || classes.pending
  }

  getStepBorderClass(status) {
    const classes = {
      pending: "border-gray-400",
      assigned: "border-blue-400",
      running: "border-yellow-400",
      completed: "border-green-400",
      failed: "border-red-400"
    }
    return classes[status] || classes.pending
  }

  getMessageBorderClass(messageType) {
    const classes = {
      "task.delegated": "border-blue-400",
      "task.acknowledgment": "border-green-400",
      "task.completion": "border-cyan-400",
      "task.progress": "border-amber-400",
      "error.notification": "border-red-400",
      "agent.log_event": "border-purple-400",
      "agent.heartbeat": "border-indigo-400"
    }
    return classes[messageType] || classes["agent.heartbeat"]
  }
}
