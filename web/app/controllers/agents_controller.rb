class AgentsController < ApplicationController
  before_action :set_agent, only: %i[show edit update destroy
                                     start stop full_cycle build_image
                                     status logs]

  def index
    @agents = Agent.includes(:env_vars).order(:name)
  end

  def show
    @agent_runs = @agent.agent_runs.order(created_at: :desc).limit(20)
  end

  def new
    @agent = Agent.new
    3.times { @agent.env_vars.build }
  end

  def edit
    @agent.env_vars.build if @agent.env_vars.none?
  end

  def create
    @agent = Agent.new(agent_params)
    if @agent.save
      redirect_to @agent, notice: "Agent \"#{@agent.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @agent.update(agent_params)
      redirect_to @agent, notice: "Agent \"#{@agent.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @agent.destroy
    redirect_to agents_path, notice: "Agent deleted."
  end

  # ---- Async operations ----

  def start
    run = @agent.agent_runs.create!(action: "start", status: "pending",
                                    started_at: Time.current)
    @agent.update!(status: "pending")
    StartAgentJob.perform_later(@agent.id, run.id)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @agent, notice: "Starting #{@agent.name}..." }
    end
  end

  def stop
    run = @agent.agent_runs.create!(action: "stop", status: "pending",
                                    started_at: Time.current)
    @agent.update!(status: "pending")
    StopAgentJob.perform_later(@agent.id, run.id)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @agent, notice: "Stopping #{@agent.name}..." }
    end
  end

  def full_cycle
    run = @agent.agent_runs.create!(action: "full_cycle", status: "pending",
                                    started_at: Time.current)
    @agent.update!(status: "pending")
    FullCycleJob.perform_later(@agent.id, run.id)
    redirect_to @agent, notice: "Full cycle queued for #{@agent.name}."
  end

  def build_image
    run = @agent.agent_runs.create!(action: "build", status: "pending",
                                    started_at: Time.current)
    BuildImageJob.perform_later(@agent.id, run.id)
    redirect_to @agent, notice: "Build queued for #{@agent.name}."
  end

  # ---- Live data endpoints ----

  def status
    orchestrator = Cocina::Orchestrator.from_records([@agent])
    render json: orchestrator.agent_status(@agent.name)
  end

  def logs
    stdout, _, _ = Cocina::Orchestrator.new.run_command(
      ["docker", "logs", "--tail", "100", @agent.name]
    )
    render plain: stdout
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end

  def agent_params
    params.require(:agent).permit(
      :name, :description, :image, :command,
      :build_context, :externals, :task,
      ports: [],
      env_vars_attributes: [:id, :key, :value, :_destroy]
    )
  end
end
