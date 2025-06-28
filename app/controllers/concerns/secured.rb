module Secured
  extend ActiveSupport::Concern

  included do
    before_action :logged_in_using_omniauth?
  end

  private

  def logged_in_using_omniauth?
    return if session[:authenticated] == true

    # 既にAuth0へのリダイレクト中の場合はスキップ
    return if request.path.start_with?("/auth/")

    redirect_to_login
  end

  def redirect_to_login
    redirect_to "/auth/auth0"
  end
end
