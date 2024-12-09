class GmailService
  include HTTParty
  base_uri 'https://www.googleapis.com'

  # OAuth URLs and Scopes
  AUTHORIZE_URL = 'https://accounts.google.com/o/oauth2/auth'.freeze
  TOKEN_URL = 'https://oauth2.googleapis.com/token'.freeze
  USERINFO_URL = 'https://www.googleapis.com/oauth2/v3/userinfo'.freeze
  GMAIL_API_BASE = '/gmail/v1/users/me'.freeze
  SCOPE = [
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify'
  ].join(' ').freeze

  def initialize
    load_service_credentials
  end

  def authorization_url
    query_params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      scope: SCOPE,
      response_type: 'code',
      access_type: 'offline',
      prompt: 'consent'
    }
    build_url(AUTHORIZE_URL, query_params)
  end

  def get_access_token(code)
    response = self.class.post(TOKEN_URL, body: token_request_body(code: code, grant_type: 'authorization_code'))
    handle_response(response) do |parsed_response|
      email = fetch_user_email(parsed_response['access_token'])
      {
        access_token: parsed_response['access_token'],
        refresh_token: parsed_response['refresh_token'],
        email: email,
        expires_at: Time.now + parsed_response['expires_in'].to_i
      }
    end
  end

  def refresh_access_token(refresh_token)
    response = self.class.post(TOKEN_URL, body: token_request_body(refresh_token: refresh_token, grant_type: 'refresh_token'))
    handle_response(response) do |parsed_response|
      {
        access_token: parsed_response['access_token'],
        expires_at: Time.now + parsed_response['expires_in'].to_i,
        refresh_token: parsed_response['refresh_token']
      }
    end
  end

  def fetch_unread_emails(access_token)
    response = self.class.get("#{GMAIL_API_BASE}/messages",
                              headers: authorization_header(access_token),
                              query: { q: 'is:unread' })
    handle_response(response) do |parsed_response|
      messages = parsed_response['messages'] || []
      messages.map { |msg| get_message_details(msg['id'], access_token) }
    end
  end

  def get_message_details(message_id, access_token)
    response = self.class.get("#{GMAIL_API_BASE}/messages/#{message_id}", headers: authorization_header(access_token))
    handle_response(response) do |parsed_response|
      extract_message_details(parsed_response, message_id)
    end
  end

  def mark_as_read(message_id, access_token)
    url = "#{GMAIL_API_BASE}/messages/#{message_id}/modify"
    body = { removeLabelIds: ['UNREAD'] }.to_json
    response = self.class.post(url, headers: authorization_header(access_token), body: body)
    handle_response(response) { "Email marked as read successfully." }
  end

  private

  def load_service_credentials
    @gmail_service_secret = MailTicketProvider.find_by(name: 'gmail')
    raise 'Gmail service secret not found' unless @gmail_service_secret

    @client_id = @gmail_service_secret.client_id
    @client_secret = @gmail_service_secret.client_secret
    @redirect_uri = @gmail_service_secret.callback_url
  end

  def fetch_user_email(access_token)
    response = self.class.get(USERINFO_URL, headers: authorization_header(access_token))
    handle_response(response) { |parsed_response| parsed_response['email'] }
  end

  def extract_message_details(message, message_id)
    headers = message['payload']['headers']
    {
      from: fetch_header(headers, 'From'),
      received_at: fetch_header(headers, 'Date'),
      subject: fetch_header(headers, 'Subject'),
      body: message['snippet'],
      id: message_id,
    }
  end

  def token_request_body(params)
    {
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_uri
    }.merge(params)
  end

  def authorization_header(token)
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  def handle_response(response)
    if response.success?
      yield JSON.parse(response.body)
    else
      raise "Request failed: #{response.code} #{response.body}"
    end
  end

  def fetch_header(headers, key)
    header = headers.find { |h| h['name'] == key }
    header ? header['value'] : nil
  end

  def build_url(base_url, params)
    URI.parse(base_url).tap { |uri| uri.query = URI.encode_www_form(params) }.to_s
  end
end