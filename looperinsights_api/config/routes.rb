Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  resources :shows, only: [ :index, :show ] do
    collection do
      get :query  # /api/shows/query
    end
  end

  resources :episodes, only: [ :index, :show ]
  # Defines the root path route ("/")
  # root "posts#index"
end
