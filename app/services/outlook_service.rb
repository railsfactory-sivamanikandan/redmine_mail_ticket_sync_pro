class OutlookService
  GRAPH_API_BASE = 'https://graph.microsoft.com/v1.0'.freeze

  def initialize
    @outlook_service_secret = MailTicketProvider.find_by(name: 'outlook')
    raise 'Outlook service secret not found' unless @outlook_service_secret

    @client_id = @outlook_service_secret.client_id
    @client_secret = @outlook_service_secret.client_secret
    @tenant_id = @outlook_service_secret.tenant_id
    @redirect_uri = @outlook_service_secret.callback_url
  end

  # Generate the authorization URL
  def authorization_url
    client.auth_code.authorize_url(
      redirect_uri: @redirect_uri,
      scope: scope
    )
  end

  # Exchange authorization code for access token
  def get_access_token(code)
    token = client.auth_code.get_token(
      code,
      redirect_uri: @redirect_uri
    )
    decode_token(token)
  rescue OAuth2::Error => e
    Rails.logger.error("OAuth Error: #{e.message}")
    nil
  end

  # Fetch unread emails from Outlook inbox
  def fetch_inbox_emails
    uri = "#{GRAPH_API_BASE}/me/messages?$filter=isRead eq false"

    response = make_request(uri, :get)
    if response.success?
      parse_emails(response.parsed_response['value'])
    else
      handle_error("Failed to fetch unread emails", response)
      []
    end
  end

  private

  # Parse email details
  def parse_emails(emails)
    emails.map do |email|
      {
        subject: email['subject'],
        from: email.dig('from', 'emailAddress', 'address'),
        received_at: email['receivedDateTime'],
        description: email['bodyPreview'],
        id: email['id']
      }
    end
  end

  # Create an OAuth2 client
  def client
    @client ||= OAuth2::Client.new(
      @client_id,
      @client_secret,
      site: 'https://login.microsoftonline.com',
      authorize_url: "#{@tenant_id}/oauth2/v2.0/authorize",
      token_url: "#{@tenant_id}/oauth2/v2.0/token"
    )
  end

  # Make a request to the Graph API
  def make_request(uri, method, headers = {}, body = {})
    HTTParty.send(method, uri, {
      headers: default_headers.merge(headers),
      body: body.to_json
    })
  end

  # Decode the OAuth token and return its details
  def decode_token(token)
    {
      access_token: token.token,
      refresh_token: token.refresh_token,
      expires_at: Time.at(token.expires_at)
    }
  end

  # Default headers for requests
  def default_headers
    { 'Content-Type' => 'application/json' }
  end

  # OAuth2 scope for the application
  def scope
    'https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/User.Read'
  end

  # Handle errors and log details
  def handle_error(message, response)
    Rails.logger.error("#{message}: #{response.body}")
    @job.update!(sync_status: 3, message: response.body) if defined?(@job)
  end
end