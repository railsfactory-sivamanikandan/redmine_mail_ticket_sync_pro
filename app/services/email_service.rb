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
    emails = fetch_emails
    return unless emails

    emails.each { |email| create_issue(email) }
    update_job_status(emails.count)
  end

  private

  # Refresh the access token if it's expired
  def refresh_token_if_expired
    return unless token_expired?

    Rails.logger.error('Access token expired, refreshing...')
    if (response = refresh_access_token)
      @job.mail_ticket_token.update!(access_token: response[:access_token], expires_at: response[:expires_at], refresh_token: response[:refresh_token])
    else
      handle_token_refresh_failure
    end
  end

  # Check if the token is expired
  def token_expired?
    @job.expires_at < Time.now
  end

  # Refresh the access token and update the job
  def refresh_access_token
    response = service.refresh_access_token(@job.mail_ticket_token.refresh_access_token)
    return unless response

    @access_token = response[:access_token]
    response
  end

  # Handle failure to refresh the token
  def handle_token_refresh_failure
    Rails.logger.error('Failed to refresh token')
    @job.update!(sync_status: 3, message: 'Failed to refresh token')
  end

  # Fetch unread emails using the service
  def fetch_emails
    response = service.fetch_unread_emails(@access_token)
    if response
      response
    else
      Rails.logger.error('Failed to fetch unread emails')
      @job.update!(sync_status: 3, message: 'Failed to fetch unread emails')
      nil
    end
  end

  # Create a Redmine issue for each email
  def create_issue(email)
    issue = @project.issues.new(
      subject: email[:subject],
      description: email[:body],
      status_id: 1, # Open status (can change depending on your workflow)
      author_id: 1, # Set to an appropriate user ID
      tracker_id: @tracker,
      priority_id: @priority,
      assigned_to_id: @assigned_to
    )

    if issue.save
      Rails.logger.info("Issue created for email: #{email[:subject]}")
      mark_email_as_read(email[:id])
    else
      log_issue_creation_failure(email[:subject])
    end
  end

  # Mark the email as read after creating the issue
  def mark_email_as_read(email_id)
    service.mark_as_read(email_id, @access_token) if email_id
  end

  # Log an error when issue creation fails
  def log_issue_creation_failure(subject)
    Rails.logger.error("Failed to create issue for email: #{subject}")
    @job.update!(sync_status: 3, message: "Failed to create issue for email: #{subject}")
  end

  # Update the job status after processing emails
  def update_job_status(email_count)
    @job.update!(
      inbox_last_sync_at: Time.now,
      last_sync_email_count: email_count,
      sync_status: 2
    )
  end

  # Initialize the service based on the provider
  def service
    @service ||= case @provider
                 when 'gmail'
                   GmailService.new
                 when 'outlook'
                   OutlookService.new
                 else
                   raise "Unsupported provider: #{@provider}"
                 end
  end
end
