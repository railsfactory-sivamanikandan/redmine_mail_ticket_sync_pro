class OutlookService
  GRAPH_API_BASE = 'https://graph.microsoft.com/v1.0'.freeze
  AUTH_BASE_URL = 'https://login.microsoftonline.com'.freeze

  def initialize
    setup_service_credentials
  end

  # Generate the authorization URL
  def authorization_url
    oauth_client.auth_code.authorize_url(
      redirect_uri: @redirect_uri,
      scope: oauth_scope
    )
  end

  # Exchange authorization code for access token
  def get_access_token(code)
    token = oauth_client.auth_code.get_token(code, redirect_uri: @redirect_uri)
    decode_token(token)
  rescue OAuth2::Error => e
    log_error("OAuth Error: #{e.message}")
    nil
  end

  # Fetch unread emails from Outlook inbox
  def fetch_unread_emails(access_token)
    uri = "#{GRAPH_API_BASE}/me/messages?$filter=isRead eq false"
    response = make_request(uri, :get, access_token)
    handle_response(response) do |body|
      parse_emails(body['value'])
    end
  end

  # Mark an email as read
  def mark_as_read(message_id, access_token)
    uri = "#{GRAPH_API_BASE}/me/messages/#{message_id}"
    body = { isRead: true }.to_json
    response = make_request(uri, :patch, access_token, body)
    handle_response(response) do
      log_info("Email #{message_id} marked as read.")
    end
  end

  # Refresh the access token using the refresh token
  def refresh_access_token(refresh_token)
    uri = "#{AUTH_BASE_URL}/#{@tenant_id}/oauth2/v2.0/token"
    body = token_refresh_body(refresh_token)
    response = HTTParty.post(uri, body: body, headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })
    handle_response(response) do |body|
      {
        access_token: body['access_token'],
        expires_in: body['expires_in'],
        refresh_token: body['refresh_token']
      }
    end
  end

  private

  def setup_service_credentials
    @outlook_service_secret = MailTicketProvider.find_by(name: 'outlook')
    raise 'Outlook service secret not found' unless @outlook_service_secret

    @client_id = @outlook_service_secret.client_id
    @client_secret = @outlook_service_secret.client_secret
    @tenant_id = @outlook_service_secret.tenant_id
    @redirect_uri = @outlook_service_secret.callback_url
  end

  # Create an OAuth2 client
  def oauth_client
    @oauth_client ||= OAuth2::Client.new(
      @client_id,
      @client_secret,
      site: AUTH_BASE_URL,
      authorize_url: "#{@tenant_id}/oauth2/v2.0/authorize",
      token_url: "#{@tenant_id}/oauth2/v2.0/token"
    )
  end

  # OAuth2 scope for the application
  def oauth_scope
    'user.read mail.readwrite offline_access'
  end

  # Decode the OAuth token and return its details
  def decode_token(token)
    user_info = JWT.decode(token.token, nil, false).first
    {
      access_token: token.token,
      refresh_token: token.refresh_token,
      expires_at: Time.at(token.expires_at),
      email: user_info['unique_name']
    }
  end

  # Parse email details
  def parse_emails(emails)
    emails.map do |email|
      {
        subject: email['subject'],
        from: email.dig('from', 'emailAddress', 'address'),
        received_at: email['receivedDateTime'],
        body: email['bodyPreview'],
        id: email['id']
      }
    end
  end

  # Handle HTTP requests to the Graph API
  def make_request(uri, method, access_token, body = nil)
    options = {
      headers: {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json'
      }
    }
    options[:body] = body if body
    HTTParty.send(method, uri, options)
  end

  # Prepare the token refresh body
  def token_refresh_body(refresh_token)
    {
      client_id: @client_id,
      client_secret: @client_secret,
      refresh_token: refresh_token,
      grant_type: 'refresh_token',
      scope: 'https://graph.microsoft.com/.default'
    }
  end

  # Centralized response handling
  def handle_response(response)
    if response.success?
      yield response.parsed_response
    else
      handle_error("API request failed", response)
      nil
    end
  end

  # Handle errors gracefully and log details
  def handle_error(message, response)
    raise "Request failed: #{response.code} #{response.body}"
  end

  # Log general info
  def log_info(message)
    Rails.logger.info(message)
  end

  # Log specific errors
  def log_error(message)
    Rails.logger.error(message)
  end
end