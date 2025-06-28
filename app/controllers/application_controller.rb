class ApplicationController < ActionController::Base
  # Rails 8 では標準でCSRF保護が有効
  protect_from_forgery with: :exception

  # Rails 8では allow_browser も利用可能
  # allow_browser versions: :modern

  include Secured

  private

  def current_user
    return nil unless session[:authenticated]

    @current_user ||= {
      "uid" => session[:user_id],
      "provider" => session[:provider],
      "info" => {
        "name" => session[:user_name],
        "email" => session[:user_email],
        "picture" => session[:user_picture]
      }
    }
  end

  def logged_in?
    session[:authenticated] == true
  end

  helper_method :current_user, :logged_in?
end
