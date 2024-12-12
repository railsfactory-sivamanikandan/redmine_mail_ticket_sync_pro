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

    success_count = 0
    errors = []

    emails.each do |email|
      create_response = create_issue(email)
      success_count += 1 if create_response[:created]
      errors << create_response[:error] unless create_response[:created]
    end

    update_job_status(success_count, errors)
  end

  private

  def refresh_token_if_expired
    return unless token_expired?

    Rails.logger.error('Access token expired, refreshing...')
    response = refresh_access_token
    if response
      update_job_with_new_token(response)
    else
      handle_token_refresh_failure
    end
  end

  def token_expired?
    @ticket_token.expires_at < Time.current
  end

  def refresh_access_token
    response = service.refresh_access_token(@job.mail_ticket_token.refresh_access_token)
    response&.tap { @access_token = response[:access_token] }
  end

  def update_job_with_new_token(response)
    expires_at = @provider == 'outlook' ? response[:expires_in] : response[:expires_at]
    @job.mail_ticket_token.update!(
      access_token: response[:access_token],
      expires_at: expires_at,
    )
  end

  def handle_token_refresh_failure
    Rails.logger.error('Failed to refresh token')
    @job.update!(sync_status: 3, message: 'Failed to refresh token')
  end

  def fetch_emails
    response = service.fetch_unread_emails(@access_token)
    if response
      response
    else
      log_error('Failed to fetch unread emails')
      @job.update!(sync_status: 3, message: 'Failed to fetch unread emails')
      nil
    end
  end

  def create_issue(email)
    author = find_or_create_user_from_attributes( email[:from],email[:first_name], email[:last_name])
    issue = @project.issues.new(issue_params(email, author))

    available_custom_fields = IssueCustomField.where(
      id: @job.tracker.custom_field_ids & @project.all_issue_custom_fields.pluck(:id)
    )

    issue.safe_attributes = {custom_field_values: build_custom_field_parameters(available_custom_fields)}

    if issue.save
      add_attachments(email, issue, author)
      Rails.logger.info("Issue created for email: #{email[:subject]}")
      mark_email_as_read(email[:id])
      { created: true }
    else
      log_issue_creation_failure(email[:subject], issue)
    end
  end

  def issue_params(email, author)
    author_id = author.try(:id) || 1
    start_date ||= User.current.today if Setting.default_issue_start_date_to_creation_date?

    {
      subject: email[:subject],
      description: email[:body],
      status_id: 1, # Open status
      author_id: author_id,
      tracker_id: @tracker,
      priority_id: @priority,
      assigned_to_id: @assigned_to,
      start_date: start_date,
    }
  end

  def build_custom_field_parameters(available_custom_fields)
    custom_field_values = {}
    available_custom_fields.each do |field|
      value = field.default_value.presence

      if field.field_format == 'list' && field.possible_values.present?
        value ||= field.possible_values.last
      end

      if field.field_format == 'date'
        value ||= Date.today.to_s
      end

      if field.field_format == 'int'
        value = (value.presence || 0).to_i
        if field.min_length && value.to_s.length < field.min_length
          value = value.to_s.rjust(field.min_length, '1').to_i
        end
        if field.max_length && value.to_s.length > field.max_length
          value = value.to_s[0...field.max_length].to_i
        end
      end

      if field.field_format == 'float'
        value = (value.presence || 0.0).to_f
        if field.min_length
          value = sprintf("%1#{field.min_length}f", value)
        end
        if field.max_length && value.to_s.length > field.max_length
          value = value.to_s[0...field.max_length].to_f
        end
      end

      if field.field_format == 'string'
        value ||= "DefaultValue"
        if field.min_length && value.to_s.length < field.min_length
          value = value.to_s.ljust(field.min_length, '_')
        end
        if field.max_length && value.to_s.length > field.max_length
          value = value.to_s[0...field.max_length]
        end
      end

      if field.field_format == 'string' && field.regexp.present? && !Regexp.new(field.regexp).match?(value.to_s)
        value = field.possible_values&.first || "DefaultValue"
      end

      custom_field_values[field.id.to_s] = value
    end

    custom_field_values
  end

  def add_attachments(email, issue, user)
    if email[:attachments] && email[:attachments].any?
      email[:attachments].each do |attachment|
        attachment_content = Base64.decode64(attachment[:content])
        issue.attachments << Attachment.create(
          container: issue,
          file: attachment_content,
          filename: attachment[:name],
          author: user,
          content_type: attachment[:content_type]
        )
      end
    end
  end

  def find_or_create_user_from_attributes(email_address, firstname=nil, lastname=nil)
    user = User.find_by_mail(email_address)
    unless user
      user = User.new
      user.mail = email_address
      user.login = email_address[0, User::LOGIN_LENGTH_LIMIT]
      user.firstname = (firstname.presence || "-")[0, 30]
      user.lastname = (lastname.presence || "-")[0, 30]
      user.language = Setting.default_language
      user.generate_password = true
      user.mail_notification = 'none'
      unless user.valid?
        user.login = "user#{Redmine::Utils.random_hex(6)}" if user.errors[:login].present?
        user.firstname = "-" if user.errors[:firstname].present?
        user.lastname = "-" if user.errors[:lastname].present?
      end
      user.save! if user.valid?
      log_error(user.errors.full_messages) unless user.valid?
    end
    user
  end

  def mark_email_as_read(email_id)
    service.mark_as_read(email_id, @access_token) if email_id
  end

  def log_error(message)
    Rails.logger.error(message)
  end

  def log_issue_creation_failure(subject, issue)
    Rails.logger.error("Failed to create issue for email: #{subject}")
    { created: false, error: issue.errors.full_messages.join(', ') }
  end

  def update_job_status(success_count, errors)
    error_msg = errors.any? ? errors.join(', ') : nil
    sync_status = error_msg.present? ? 3 : 2
    @job.update!(
      inbox_last_sync_at: Time.now,
      last_sync_email_count: success_count,
      sync_status: sync_status,
      message: error_msg
    )
  end

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
