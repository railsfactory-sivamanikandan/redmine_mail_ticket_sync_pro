require 'httparty'

class OutlookMailService
  GRAPH_API_BASE = 'https://graph.microsoft.com/v1.0'

  def initialize(job, args)
    @job = job
    @ticket_token = job.mail_ticket_token
    @access_token = job.access_token
    @project = job.project
    @tracker = args[:tracker]
    @assigned_to = args[:assigned_to]
    @priority = args[:priority]
    refresh_token_if_expired
  end

  # Fetch unread emails and create issues in Redmine
  def fetch_and_create_issues
    emails = fetch_unread_emails
    emails.each do |email|
      create_issue(email)
      mark_email_as_read(email[:id])
    end
    @job.update!(inbox_last_sync_at: Time.now, last_sync_email_count: emails.count, sync_status: 2)
    emails.count
  end

  private

  # Fetch unread emails
  def fetch_unread_emails
    uri = "#{GRAPH_API_BASE}/me/messages?$filter=isRead eq false"

    response = make_request(uri, :get)

    if response.success?
      emails = response.parsed_response['value']
      emails.map do |email|
        {
          subject: email['subject'],
          from: email.dig('from', 'emailAddress', 'address'),
          received_at: email['receivedDateTime'],
          body_preview: email['bodyPreview'],
          id: email['id'],
        }
      end
    else
      Rails.logger.error("Failed to fetch unread emails: #{response.body}")
      @job.update!(sync_status: 3, message: response.body)
      []
    end
  end

  def make_request(uri, method, body = nil)
    options = {
      headers: {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json'
      }
    }
    options[:body] = body if body

    case method
    when :get
      HTTParty.get(uri, options)
    when :patch
      HTTParty.patch(uri, options)
    else
      raise "Unsupported HTTP method: #{method}"
    end
  end

  def mark_email_as_read(email_id)
    uri = "#{GRAPH_API_BASE}/me/messages/#{email_id}"
    
    # Body to mark the email as read
    body = { isRead: true }.to_json

    response = make_request(uri, :patch, body)
    if response.success?
      Rails.logger.info("Email #{email_id} marked as read.")
    else
      Rails.logger.error("Failed to mark email #{email_id} as read: #{response.body}")
    end
  end

  # Create an issue in Redmine for the email
  def create_issue(email)
    issue = @project.issues.new(
      subject: email[:subject],
      description: email[:body_preview],
      status_id: 1,  # Open status (can change depending on your workflow)
      author_id: 1,   # Set to an appropriate user ID
      tracker_id: @tracker,
      priority_id: @priority,
      assigned_to_id: @assigned_to,
    )

    if issue.save
      Rails.logger.info("Issue created for email: #{email[:subject]}")
    else
      Rails.logger.error("Failed to create issue for email: #{email[:subject]}")
      @job.update!(sync_status: 3, message: "Failed to create issue for email: #{email[:subject]}")
    end
  end

  # Check token expiration and refresh if needed
  def refresh_token_if_expired
    return unless token_expired?

    Rails.logger.error('Access token expired, refreshing...')
    token_data = refresh_access_token

    if token_data
      update_outlook_configuration(token_data)
    else
      Rails.logger.error('Failed to refresh token')
      @job.update!(sync_status: 3, message: 'Failed to refresh token')
    end
  end

  def token_expired?
    @job.expires_at < Time.now
  end

  def refresh_access_token
    client = oauth_client
    token = OAuth2::AccessToken.new(client, @ticket_token.refresh_token)
    refreshed_token = token.refresh!
    {
      access_token: refreshed_token.token,
      refresh_token: refreshed_token.refresh_token,
      expires_at: refreshed_token.expires_at
    }
  rescue OAuth2::Error => e
    Rails.logger.error("Token refresh failed: #{e.message}")
    @job.update!(sync_status: 3, message: e.message)
    nil
  end

  def oauth_client
    @secret = MailTicketProvider.find_by(name: 'outlook')
    @oauth_client ||= OAuth2::Client.new(
      @secret.client_id,
      @secret.client_secret,
      site: 'https://login.microsoftonline.com',
      token_url: "#{@secret.tenant_id}/oauth2/v2.0/token"
    )
  end

  def update_outlook_configuration(token_data)
    @ticket_token.update!(
      access_token: token_data[:access_token],
      refresh_token: token_data[:refresh_token],
      expires_at: Time.at(token_data[:expires_at])
    )
    @access_token = token_data[:access_token]
  end
end
