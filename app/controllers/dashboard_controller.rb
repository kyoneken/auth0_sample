class DashboardController < ApplicationController
  # 一時的に認証チェックを手動で行う
  before_action :require_authentication

  def index
    Rails.logger.info "DashboardController#index called"
    @user_info = current_user
  end

  private

  def require_authentication
    unless session[:authenticated] == true
      Rails.logger.info "Dashboard access denied, redirecting to login"
      redirect_to "/auth/auth0"
    end
  end
end
