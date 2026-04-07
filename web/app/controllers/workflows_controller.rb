class WorkflowsController < ApplicationController
  before_action :set_workflow, only: [:show, :edit, :update, :destroy, :start]

  # GET /workflows
  def index
    @workflows = Workflow.order(created_at: :desc).page(params[:page]).per(20)
    @active_workflows = Workflow.active.count
    @completed_workflows = Workflow.finished.count
  end

  # GET /workflows/:workflow_id
  def show
    @workflow = Workflow.find_by(workflow_id: params[:id])
    return render_not_found unless @workflow

    @workflow_steps = @workflow.workflow_steps.order(:created_at)
    @messages = @workflow.agent_messages.order(created_at: :desc).limit(50).reverse
  end

  # GET /workflows/new
  def new
    @workflow = Workflow.new
    @agents = Agent.where(supports_rabbitmq: true).order(:name)
  end

  # POST /workflows
  def create
    @workflow = Workflow.new(workflow_params)
    @workflow.workflow_id = SecureRandom.uuid
    @workflow.initiated_by = current_user&.id || "system"

    if @workflow.save
      # Create workflow steps
      create_workflow_steps(@workflow, params[:workflow][:steps])

      redirect_to @workflow, notice: "Workflow created successfully."
    else
      @agents = Agent.where(supports_rabbitmq: true).order(:name)
      render :new
    end
  end

  # GET /workflows/:workflow_id/edit
  def edit
    @agents = Agent.where(supports_rabbitmq: true).order(:name)
    return render_not_found unless @workflow
  end

  # PATCH/PUT /workflows/:workflow_id
  def update
    if @workflow.update(workflow_params)
      redirect_to @workflow, notice: "Workflow updated successfully."
    else
      @agents = Agent.where(supports_rabbitmq: true).order(:name)
      render :edit
    end
  end

  # DELETE /workflows/:workflow_id
  def destroy
    @workflow.destroy
    redirect_to workflows_url, notice: "Workflow deleted successfully."
  end

  # POST /workflows/:workflow_id/start
  def start
    return render_not_found unless @workflow

    if @workflow.update(status: :running, started_at: Time.current)
      # Delegate first steps (those with no dependencies)
      start_steps = @workflow.workflow_steps.where(status: "pending").select do |step|
        step.depends_on_steps.blank? || JSON.parse(step.depends_on_steps).empty?
      rescue
        step.depends_on_steps.blank?
      end

      start_steps.each do |step|
        DelegateTaskJob.perform_later(
          @workflow.workflow_id,
          step.step_id,
          step.agent_id,
          step.description,
        )
      end

      redirect_to @workflow, notice: "Workflow started successfully."
    else
      redirect_to @workflow, alert: "Failed to start workflow."
    end
  end

  # GET /workflows/:workflow_id/messages
  def messages
    @workflow = Workflow.find_by(workflow_id: params[:workflow_id])
    return render_not_found unless @workflow

    @messages = @workflow.agent_messages.order(created_at: :desc).limit(200)

    respond_to do |format|
      format.html { render :messages }
      format.json { render json: @messages.map { |m| message_json(m) } }
    end
  end

  private

  def set_workflow
    @workflow = Workflow.find_by(workflow_id: params[:id])
    render_not_found unless @workflow
  end

  def workflow_params
    params.require(:workflow).permit(:name, :description)
  end

  def create_workflow_steps(workflow, steps_data)
    return unless steps_data.present?

    steps_data.each_with_index do |step_data, index|
      step = workflow.workflow_steps.create!(
        step_id: SecureRandom.uuid,
        task_id: "#{workflow.workflow_id}:#{index}",
        agent_id: step_data[:agent_id],
        description: step_data[:description],
        status: "pending",
        depends_on_steps: step_data[:dependencies].to_json,
      )
    end

    workflow.update(total_steps: workflow.workflow_steps.count)
  end

  def message_json(msg)
    {
      id: msg.message_id,
      type: msg.message_type,
      sender: msg.sender_agent_id,
      receiver: msg.receiver_agent_id,
      timestamp: msg.created_at.iso8601,
      payload: JSON.parse(msg.payload),
      status: msg.status,
    }
  end

  def render_not_found
    render file: "#{Rails.root}/public/404.html", status: :not_found
  end
end
