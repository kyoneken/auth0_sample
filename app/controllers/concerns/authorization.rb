module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :check_token_expiry
  end

  private

  def require_scope(required_scope)
    unless has_scope?(required_scope)
      Rails.logger.warn "Access denied. Required scope: #{required_scope}, User scopes: #{user_scopes}"
      redirect_to root_path, alert: "Access denied. Required permission: #{required_scope}"
    end
  end

  def has_scope?(scope)
    user_scopes.include?(scope)
  end

  def user_scopes
    session[:scopes] || []
  end

  def access_token
    session[:access_token]
  end

  def token_expired?
    return true unless session[:token_expires_at]

    Time.current >= session[:token_expires_at]
  end

  def check_token_expiry
    if session[:authenticated] && token_expired?
      Rails.logger.info "Access token expired, redirecting to login"
      reset_session
      redirect_to root_path, alert: "Your session has expired. Please log in again."
    end
  end

  def token_info
    return {} unless access_token

    {
      scopes: user_scopes,
      expires_at: session[:token_expires_at],
      expired: token_expired?
    }
  end

  helper_method :has_scope?, :user_scopes, :token_info, :token_expired?
end
