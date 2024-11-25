# plugins/microsoft_oauth/app/services/microsoft_oauth_service.rb
require 'oauth2'

class OutlookOauthService
  def initialize
    @secret = MailTicketProvider.find_by(name: 'outlook')
    @client = OAuth2::Client.new(
      client_id,
      client_secret,
      site: 'https://login.microsoftonline.com',
      authorize_url: "#{tenant_id}/oauth2/v2.0/authorize",
      token_url: "#{tenant_id}/oauth2/v2.0/token"
    )
  end

  # Generate authorization URL
  def authorization_url(scope)
    @client.auth_code.authorize_url(
      redirect_uri: callback_url,
      scope: scope
    )
  end

  # Fetch token using authorization code
  def fetch_token(code)
    token = @client.auth_code.get_token(
      code,
      redirect_uri: callback_url
    )
    decode_token(token)
  rescue OAuth2::Error => e
    Rails.logger.error("OAuth Error: #{e.message}")
    nil
  end  

  private

  # Decode JWT token and extract user information
  def decode_token(token)
    user_info = JWT.decode(token.token, nil, false).first
    {
      access_token: token.token,
      refresh_token: token.refresh_token,
      expires_at: Time.at(token.expires_at),
      email: user_info['unique_name']
    }
  rescue JWT::DecodeError => e
    Rails.logger.error("JWT Decode Error: #{e.message}")
    nil
  end

  # Environment-specific configurations
  def client_id
    @secret.client_id
  end

  def client_secret
    @secret.client_secret
  end

  def tenant_id
    @secret.tenant_id
  end

  def callback_url
    @secret.callback_url
  end
end
