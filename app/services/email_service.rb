class EmailService
  def initialize(job, args)
    @job = job
    @ticket_token = job.mail_ticket_token
    @provider = job.provider_name.downcase
    @access_token = job.access_token
    @project = job.project
    @tracker = args[:tracker]
    @assigned_to = args[:assigned_to]
    @priority = args[:priority]
    refresh_token_if_expired
  end

  def fetch_and_create_issues
    case @provider
    when 'gmail'
      service = GmailService.new
      emails = service.fetch_inbox_emails(@access_token)
      emails.each do |email|
        create_issue(email)
      end
    when 'outlook'
      OutlookService.fetch_emails(@access_token)
    else
      { error: 'Unsupported provider' }
    end
  end

  private

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
    case @provider
    when 'gmail'
      service = GmailService.new
      response = service.refresh_access_token(@job.ticket_token.refresh_access_token)
      @access_token = response[:new_access_token]
    when 'outlook'
      OutlookService.fetch_emails(@access_token)
    end
    @job.update!(access_token: @access_token, expires_at: response[:expires_at])
  end

  def create_issue(email)
    issue = @project.issues.new(
      subject: email[:subject],
      description: email[:body],
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
end
