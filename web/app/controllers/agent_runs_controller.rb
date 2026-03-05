class AgentRunsController < ApplicationController
  before_action :set_agent

  def index
    @agent_runs = @agent.agent_runs.order(created_at: :desc)
  end

  def show
    @agent_run = @agent.agent_runs.find(params[:id])
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end
end
