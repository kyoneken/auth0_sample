Rails.application.routes.draw do
  root "home#index"

  # Auth0 routes - 直接実装版
  get "/auth/auth0" => "auth0#login"
  get "/auth/auth0/callback" => "auth0#callback"
  get "/auth/failure" => "auth0#failure"
  get "/logout" => "auth0#logout"

  # Protected routes
  get "/dashboard" => "dashboard#index"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
