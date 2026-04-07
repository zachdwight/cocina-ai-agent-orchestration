require "rails_helper"

RSpec.describe "Workflow Integration", type: :integration do
  let(:chef) { create(:agent, name: "chef_agent", rabbitmq_queue_name: "chef_tasks") }
  let(:sous) { create(:agent, name: "sous_agent", rabbitmq_queue_name: "sous_tasks") }

  before do
    # Ensure RabbitMQ is mocked
    allow(Cocina::MessageBroker.instance).to receive(:connected?).and_return(true)
    allow(Cocina::MessageBroker.instance).to receive(:publish).and_return(true)
  end

  describe "Creating and managing workflows" do
    it "creates a workflow with steps" do
      workflow = Workflow.create!(
        workflow_id: SecureRandom.uuid,
        name: "Test Workflow",
        description: "A test workflow",
        status: "pending",
        total_steps: 2
      )

      step1 = workflow.workflow_steps.create!(
        step_id: SecureRandom.uuid,
        agent_id: chef.name,
        description: "Plan meal",
        status: "pending"
      )

      step2 = workflow.workflow_steps.create!(
        step_id: SecureRandom.uuid,
        agent_id: sous.name,
        description: "Cook meal",
        status: "pending",
        depends_on_steps: [step1.step_id].to_json
      )

      expect(workflow.workflow_steps.count).to eq(2)
      expect(workflow.total_steps).to eq(2)
      expect(workflow.status).to eq("pending")
    end

    it "starts a workflow and delegates first steps" do
      workflow = create_test_workflow

      expect(DelegateTaskJob).to receive(:perform_later).with(
        workflow.workflow_id,
        kind_of(String),
        chef.name,
        "Plan meal"
      )

      # Trigger start (in real app, this happens via controller)
      step = workflow.workflow_steps.first
      DelegateTaskJob.perform_later(workflow.workflow_id, step.step_id, chef.name, step.description)
    end

    it "progresses workflow through steps" do
      workflow = create_test_workflow
      step1 = workflow.workflow_steps.first
      step2 = workflow.workflow_steps.last

      # Start workflow
      workflow.update(status: :running, started_at: Time.current)

      # Step 1 completes
      step1.update(status: :assigned)
      step1.mark_completed(result: "Menu planned")

      expect(step1.reload.status).to eq("completed")
      expect(workflow.reload.completed_steps).to eq(1)

      # Step 2 should now be ready (dependencies met)
      expect(step2.dependencies_met?).to be_truthy

      # Step 2 starts and completes
      step2.update(status: :assigned)
      step2.mark_completed(result: "Meal cooked")

      expect(step2.reload.status).to eq("completed")
      expect(workflow.reload.completed_steps).to eq(2)
      expect(workflow.reload.status).to eq("completed")
    end
  end

  describe "Message logging" do
    it "logs delegated task messages" do
      agent_msg = AgentMessage.create!(
        message_id: SecureRandom.uuid,
        correlation_id: SecureRandom.uuid,
        workflow_id: SecureRandom.uuid,
        message_type: :task_delegated,
        sender_agent_id: "system",
        receiver_agent_id: chef.name,
        payload: { task_id: "task_123", task_description: "Do something" }.to_json,
        status: :received
      )

      expect(agent_msg).to be_persisted
      expect(agent_msg.message_type).to eq("task.delegated")
    end

    it "logs task completion messages" do
      agent_msg = AgentMessage.create!(
        message_id: SecureRandom.uuid,
        correlation_id: SecureRandom.uuid,
        workflow_id: SecureRandom.uuid,
        message_type: :task_completion,
        sender_agent_id: chef.name,
        receiver_agent_id: "system",
        payload: {
          task_id: "task_123",
          status: "completed",
          result: "Successfully completed"
        }.to_json,
        status: :received
      )

      expect(agent_msg).to be_persisted
      expect(agent_msg.payload_data["status"]).to eq("completed")
    end

    it "logs error messages" do
      agent_msg = AgentMessage.create!(
        message_id: SecureRandom.uuid,
        correlation_id: SecureRandom.uuid,
        workflow_id: SecureRandom.uuid,
        message_type: :error_notification,
        sender_agent_id: chef.name,
        receiver_agent_id: "system",
        payload: {
          task_id: "task_123",
          error_type: "ProcessingError",
          error_message: "Something went wrong"
        }.to_json,
        status: :received
      )

      expect(agent_msg).to be_persisted
      expect(agent_msg.message_type).to eq("error.notification")
    end
  end

  describe "Workflow state transitions" do
    it "transitions workflow from pending to running to completed" do
      workflow = create_test_workflow

      expect(workflow.status).to eq("pending")

      workflow.update(status: :running, started_at: Time.current)
      expect(workflow.reload.status).to eq("running")

      workflow.update(status: :completed, completed_at: Time.current)
      expect(workflow.reload.status).to eq("completed")
    end

    it "handles workflow failure" do
      workflow = create_test_workflow
      workflow.update(status: :running)

      workflow.mark_failed("Step failed unexpectedly")

      expect(workflow.reload.status).to eq("failed")
      expect(workflow.error_message).to include("failed")
    end
  end

  describe "Step dependencies" do
    it "identifies steps ready to run" do
      workflow = create_test_workflow
      step1 = workflow.workflow_steps[0]
      step2 = workflow.workflow_steps[1]

      # Step 1 has no dependencies
      expect(step1.dependencies_met?).to be_truthy

      # Step 2 depends on step 1
      expect(step2.dependencies_met?).to be_falsy

      # Mark step 1 as complete
      step1.mark_completed

      # Now step 2 dependencies are met
      expect(step2.reload.dependencies_met?).to be_truthy
    end

    it "calculates step duration" do
      step = create(:workflow_step)
      step.update(started_at: 10.minutes.ago, completed_at: 5.minutes.ago)

      duration = step.duration
      expect(duration).to be_between(299, 301) # 300 seconds ± 1
    end
  end

  describe "Message processing" do
    it "processes task.completion message and updates step" do
      workflow = create_test_workflow
      step = workflow.workflow_steps.first

      step.update(status: :assigned, started_at: Time.current)

      # Create and process completion message
      message = {
        message_type: "task.completion",
        message_id: SecureRandom.uuid,
        correlation_id: SecureRandom.uuid,
        workflow_id: workflow.workflow_id,
        agent_id: chef.name,
        timestamp: Time.current.iso8601,
        payload: {
          task_id: "#{workflow.workflow_id}:0",
          status: "completed",
          result: "Task completed successfully"
        }
      }

      # Simulate message processing (simplified)
      # In real app, ProcessAgentMessagesJob does this
      task_id = message[:payload][:task_id]
      parts = task_id.split(":")
      step_id = parts.last
      found_step = WorkflowStep.find_by(step_id: step_id)

      if found_step
        found_step.mark_completed(result: message[:payload][:result])
      end

      expect(step.reload.status).to eq("completed")
      expect(workflow.reload.completed_steps).to eq(1)
    end
  end

  # Helper methods

  def create_test_workflow
    workflow = Workflow.create!(
      workflow_id: SecureRandom.uuid,
      name: "Test Workflow",
      status: "pending",
      total_steps: 2
    )

    step1 = workflow.workflow_steps.create!(
      step_id: SecureRandom.uuid,
      agent_id: chef.name,
      description: "Plan meal",
      status: "pending"
    )

    step2 = workflow.workflow_steps.create!(
      step_id: SecureRandom.uuid,
      agent_id: sous.name,
      description: "Cook meal",
      status: "pending",
      depends_on_steps: [step1.step_id].to_json
    )

    workflow
  end
end

# Factory definitions (add to spec/factories/workflows.rb)
FactoryBot.define do
  factory :workflow do
    workflow_id { SecureRandom.uuid }
    name { "Test Workflow" }
    status { "pending" }
    total_steps { 1 }
  end

  factory :workflow_step do
    step_id { SecureRandom.uuid }
    workflow_id { SecureRandom.uuid }
    agent_id { "test_agent" }
    description { "Test step" }
    status { "pending" }
  end

  factory :agent do
    name { "test_agent" }
    description { "Test Agent" }
    image { "test:latest" }
    command { "python test.py" }
    status { "stopped" }
    supports_rabbitmq { true }
    mode { "hybrid" }
  end
end
