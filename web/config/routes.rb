Rails.application.routes.draw do
  root "dashboard#index"

  resources :agents do
    member do
      post :start
      post :stop
      post :full_cycle
      post :build_image
      get  :status
      get  :logs
    end

    resources :agent_runs, only: [:index, :show]
  end

  # Workflows
  resources :workflows, param: :id do
    member do
      post :start
      get :messages
    end
  end

  # Helper route for workflow paths
  def workflow_path(workflow)
    workflows_path(workflow.is_a?(String) ? workflow : workflow.workflow_id)
  end

  # ActionCable
  mount ActionCable.server => "/cable"
end
