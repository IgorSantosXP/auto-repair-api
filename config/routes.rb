Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"

      resources :customers do
        resources :vehicles, only: [:index]
      end
      resources :vehicles

      resources :services

      resources :service_orders, except: [:destroy] do
        member do
          post :deliver
          get  :saga
        end
      end

      namespace :customer do
        resources :service_orders, param: :uuid, only: [:index, :show]
      end

      get "reports/metrics", to: "reports#metrics"
    end
  end
end
