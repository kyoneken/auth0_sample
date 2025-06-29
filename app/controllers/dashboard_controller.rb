class DashboardController < ApplicationController
  before_action :check_dashboard_access

  def index
    Rails.logger.info "DashboardController#index called"
    Rails.logger.info "User scopes: #{session[:scopes] || []}"
    @user_info = current_user
  end

  private

  def check_dashboard_access
    required_scope = "read:dashboard"
    user_scopes = session[:scopes] || []

    unless user_scopes.include?(required_scope)
      Rails.logger.warn "Access denied. Required scope: #{required_scope}, User scopes: #{user_scopes}"
      redirect_to root_path, alert: "Access denied. Required permission: #{required_scope}"
    end
  end

  # 一時的なヘルパーメソッド
  def has_scope?(scope)
    user_scopes = session[:scopes] || []
    user_scopes.include?(scope)
  end

  def user_scopes
    session[:scopes] || []
  end

  def token_info
    {
      scopes: session[:scopes] || [],
      expires_at: session[:token_expires_at],
      expired: token_expired?
    }
  end

  def token_expired?
    return true unless session[:token_expires_at]
    Time.current >= session[:token_expires_at]
  end

  helper_method :has_scope?, :user_scopes, :token_info, :token_expired?
end
