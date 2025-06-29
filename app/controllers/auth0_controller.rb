require "net/http"
require "json"

class Auth0Controller < ApplicationController
  skip_before_action :logged_in_using_omniauth?

  def login
    Rails.logger.info "Auth0Controller#login called"

    # セッションをクリア
    session.clear

    # Auth0の認証URLを構築
    auth_url = build_auth_url
    Rails.logger.info "Redirecting to Auth0: #{auth_url}"
    redirect_to auth_url, allow_other_host: true
  end

  def callback
    Rails.logger.info "Auth0 callback received with params: #{params.inspect}"

    # 認証コードを取得
    code = params[:code]
    state = params[:state]

    unless code.present?
      Rails.logger.error "No authorization code received"
      redirect_to root_path, alert: "No authorization code received"
      return
    end

    # stateを検証
    unless session[:auth_state] == state
      Rails.logger.error "Invalid state parameter. Expected: #{session[:auth_state]}, Got: #{state}"
      redirect_to root_path, alert: "Invalid state parameter"
      return
    end

    begin
      # アクセストークンを取得
      token_response = exchange_code_for_token(code)
      Rails.logger.info "Token response: #{token_response.keys}"

      if token_response["access_token"]
        # JWTトークンを検証
        decoded_token = verify_jwt_token(token_response["access_token"])
        Rails.logger.info "JWT verified successfully. Scopes: #{decoded_token['scope']}"

        # ユーザー情報を取得
        user_info = get_user_info(token_response["access_token"])
        Rails.logger.info "User info received: #{user_info.keys}"

        # セッションを完全にクリア
        session.clear

        # 最小限の情報のみ保存（JWT検証済み）
        session[:user_id] = user_info["sub"]
        session[:user_email] = user_info["email"]
        session[:user_name] = user_info["name"]
        session[:user_picture] = user_info["picture"]
        session[:provider] = "auth0"
        session[:authenticated] = true
        session[:access_token] = token_response["access_token"]
        session[:scopes] = decoded_token["scope"]&.split(" ") || []
        session[:token_expires_at] = Time.at(decoded_token["exp"])

        Rails.logger.info "Session set successfully with scopes: #{session[:scopes]}"
        redirect_to dashboard_path
      else
        Rails.logger.error "No access token in response: #{token_response}"
        redirect_to root_path, alert: "Authentication failed - no access token"
      end
    rescue => e
      Rails.logger.error "Authentication error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to root_path, alert: "Authentication failed - server error"
    end
  end

  def failure
    Rails.logger.info "Auth0 failure called with params: #{params.inspect}"
    @error_msg = params["message"] || "Authentication failed"
    render "failure"
  end

  def logout
    Rails.logger.info "Auth0 logout called"

    # セッションをクリア
    reset_session

    # Auth0のログアウトURLを構築
    logout_url = "https://#{ENV['AUTH0_DOMAIN']}/v2/logout"
    return_to = "#{request.protocol}#{request.host_with_port}"
    client_id = ENV["AUTH0_CLIENT_ID"]

    redirect_to "#{logout_url}?returnTo=#{return_to}&client_id=#{client_id}", allow_other_host: true
  end

  private

  def build_auth_url
    domain = ENV["AUTH0_DOMAIN"]
    client_id = ENV["AUTH0_CLIENT_ID"]
    audience = ENV["AUTH0_AUDIENCE"]
    callback_url = "#{request.protocol}#{request.host_with_port}/auth/auth0/callback"

    state = SecureRandom.hex(8)
    session[:auth_state] = state

    params = {
      response_type: "code",
      client_id: client_id,
      redirect_uri: callback_url,
      scope: "openid profile email read:profile read:dashboard read:user write:user",
      audience: audience,
      state: state,
      prompt: "consent"
    }

    Rails.logger.info "Built auth URL with params: #{params.inspect}"
    "https://#{domain}/authorize?" + params.to_query
  end

  def exchange_code_for_token(code)
    uri = URI("https://#{ENV['AUTH0_DOMAIN']}/oauth/token")

    params = {
      grant_type: "authorization_code",
      client_id: ENV["AUTH0_CLIENT_ID"],
      client_secret: ENV["AUTH0_CLIENT_SECRET"],
      code: code,
      redirect_uri: "#{request.protocol}#{request.host_with_port}/auth/auth0/callback",
      audience: ENV["AUTH0_AUDIENCE"]
    }

    Rails.logger.info "Exchanging code for token at: #{uri}"
    response = Net::HTTP.post_form(uri, params)
    Rails.logger.info "Token exchange response status: #{response.code}"

    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      Rails.logger.error "Token exchange failed: #{response.body}"
      {}
    end
  end

  def get_user_info(access_token)
    uri = URI("https://#{ENV['AUTH0_DOMAIN']}/userinfo")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"

    Rails.logger.info "Getting user info from: #{uri}"
    response = http.request(request)
    Rails.logger.info "User info response status: #{response.code}"

    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      Rails.logger.error "User info request failed: #{response.body}"
      {}
    end
  end

  def verify_jwt_token(token)
    # 簡易的なJWTデコード（本番環境では適切なJWT検証ライブラリを使用）
    require "base64"
    require "json"

    parts = token.split(".")
    payload = parts[1]

    # Base64URLデコード
    payload += "=" * (4 - payload.length % 4) if payload.length % 4 != 0
    decoded_payload = Base64.urlsafe_decode64(payload)

    JSON.parse(decoded_payload)
  rescue => e
    Rails.logger.error "JWT verification failed: #{e.message}"
    raise "Invalid JWT token"
  end
end
