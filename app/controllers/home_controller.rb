class HomeController < ApplicationController
  skip_before_action :logged_in_using_omniauth?, only: [ :index ]

  def index
    Rails.logger.info "=== HomeController#index START ==="
    Rails.logger.info "Session authenticated: #{session[:authenticated].inspect}"

    # SSO動作: 既にログイン済みの場合は自動的にダッシュボードへリダイレクト
    if session[:authenticated] == true
      Rails.logger.info "User is authenticated, redirecting to dashboard"
      redirect_to dashboard_path
    else
      Rails.logger.info "User is not authenticated, showing home page"
    end

    Rails.logger.info "=== HomeController#index END ==="
  end
end
