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

  # ActionCable
  mount ActionCable.server => "/cable"
end
