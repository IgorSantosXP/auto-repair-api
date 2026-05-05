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

      resources :parts do
        member { get :stock }
        resources :stock_movements, only: [:index, :create]
      end

      resources :service_orders do
        member { post :transitions }
      end

      namespace :customer do
        resources :service_orders, param: :uuid, only: [:show] do
          member do
            post :approve
            post :reject
          end
        end
      end

      get "reports/metrics", to: "reports#metrics"
    end
  end
end
