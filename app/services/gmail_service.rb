class GmailService
  include HTTParty
  base_uri 'https://www.googleapis.com'

  # Define constants for OAuth URLs
  AUTHORIZE_URL = 'https://accounts.google.com/o/oauth2/auth'.freeze
  TOKEN_URL = 'https://oauth2.googleapis.com/token'.freeze
  USERINFO_URL = 'https://www.googleapis.com/oauth2/v3/userinfo'.freeze
  SCOPE = 'https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/gmail.readonly'.freeze

  # Initialize GmailService with GmailServiceSecret
  def initialize
    @gmail_service_secret = MailTicketProvider.find_by(name: 'gmail')
    raise 'Gmail service secret not found' unless @gmail_service_secret

    @client_id = @gmail_service_secret.client_id
    @client_secret = @gmail_service_secret.client_secret
    @redirect_uri = @gmail_service_secret.callback_url
  end

  # Generate authorization URL for Gmail OAuth
  def authorization_url
    query_params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      scope: SCOPE,
      response_type: 'code',
      access_type: 'offline',
      prompt: 'consent',
    }
    
    URI.parse(AUTHORIZE_URL).tap { |uri| uri.query = URI.encode_www_form(query_params) }.to_s
  end

  # Exchange authorization code for access token
  def get_access_token(code)
    response = self.class.post(TOKEN_URL, body: {
      code: code,
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_uri,
      grant_type: 'authorization_code'
    })

    if response.success?
      parsed_response = JSON.parse(response.body)

      email = fetch_user_email(parsed_response['access_token'])

      access_token = parsed_response['access_token']
      refresh_token = parsed_response['refresh_token']
      expires_at = Time.now + parsed_response['expires_in'].to_i

      { access_token: access_token, refresh_token: refresh_token, email: email, expires_at: expires_at }
    else
      raise "Failed to fetch user info: #{response.code} #{response.body}"
    end
  end

  def fetch_user_email(access_token)
    response = self.class.get(USERINFO_URL, headers: {
      "Authorization" => "Bearer #{access_token}"
    })

    if response.success?
      user_info = JSON.parse(response.body)
      user_info['email']
    else
      raise "Failed to fetch user info: #{response.code} #{response.body}"
    end
  end

  # Fetch Gmail inbox using access token
  def fetch_inbox_emails(access_token)
    response = self.class.get('/gmail/v1/users/me/messages', headers: {
      'Authorization' => "Bearer #{access_token}"
    })

    if response.success?
      messages = JSON.parse(response.body)['messages']
      messages.map do |message|
        message_id = message['id']
        message_details = get_message_details(message_id, access_token)
        
        # Extract the subject and description (snippet)
        from = message_details[:from]
        received_at = message_details[:received_at]
        subject = message_details[:subject]
        body = message_details[:body]
  
        {
          subject: subject,
          description: body,
          id: message_id,
          received_at: received_at,
          from: from,
        }
      end
    else
      raise "Failed to fetch inbox: #{response.code} #{response.body}"
    end
  end

  # Fetch message details by message ID
  def get_message_details(message_id, access_token)
    response = self.class.get("/gmail/v1/users/me/messages/#{message_id}", headers: {
      'Authorization' => "Bearer #{access_token}"
    })

    if response.success?
      message = JSON.parse(response.body)
      
      # Extract headers from the message payload
      headers = message['payload']['headers']

      # Find 'From' and 'Date' headers
      from = headers.find { |header| header['name'] == 'From' }['value']
      received_at = headers.find { |header| header['name'] == 'Date' }['value']
      
      # Extract the subject and snippet
      subject = headers.find { |header| header['name'] == 'Subject' }['value']
      snippet = message['snippet']
      

      # body = extract_body(message['payload'])

      {
        from: from,
        received_at: received_at,
        subject: subject,
        body: snippet,
        # body: body,
      }
    else
      raise "Failed to fetch message details: #{response.code} #{response.body}"
    end
  end

  def mark_as_read(message_id, access_token)
    response = self.class.post("/gmail/v1/users/me/messages/#{message_id}/modify", headers: {
      'Authorization' => "Bearer #{access_token}"
    },
    body: {
      addLabelIds: ['INBOX'],
      removeLabelIds: ['UNREAD']
    }.to_json)

    if response.success?
      puts "Email marked as read"
    else
      raise "Failed to mark email as read: #{response.code} #{response.body}"
    end
  end

  # Refresh access token using the stored refresh token
  def refresh_access_token(refresh_token)
    response = self.class.post(TOKEN_URL, body: {
      client_id: @client_id,
      client_secret: @client_secret,
      refresh_token: refresh_token,
      grant_type: 'refresh_token'
    })

    if response.success?
      parsed_response = JSON.parse(response.body)
      new_access_token = parsed_response['access_token']
      expires_at = Time.now + parsed_response['expires_in'].to_i
      {new_access_token: new_access_token, expires_at: expires_at}
    else
      raise "Failed to refresh access token: #{response.code} #{response.body}"
    end
  end
end
