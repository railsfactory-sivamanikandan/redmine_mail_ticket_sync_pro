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
    grouped_emails = group_emails_by_parent(emails)
    grouped_emails.each do |email|
      create_response = create_issue_or_add_comments(email)
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
    @job.mail_ticket_token.update!(
      access_token: response[:access_token],
      expires_at: response[:expires_at]
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

  def create_issue_or_add_comments(email)
    author = find_or_create_user_from_attributes(email[:from], email[:first_name], email[:last_name])
    existing_issue = find_existing_issue(email)

    if existing_issue
      add_comments_for_issue(email, existing_issue, author, true)
      mark_email_as_read(email[:id])
      { created: true }
    else
      create_issue(email, author)
    end
  end

  def find_existing_issue(email)
    ticket_info = email[:subject].match(/\[.*? #(\d+)\](?!\S)/)
    existing_issue = ticket_info ? Issue.find_by(id: ticket_info[1]) : nil
    existing_issue ||= Issue.find_by(email_message_id: email[:conversation_id])

    existing_issue
  end

  def create_issue(email, author)
    issue = @project.issues.new(issue_params(email, author))
    available_custom_fields = available_custom_fields_for_issue
    issue.safe_attributes = { custom_field_values: build_custom_field_parameters(available_custom_fields) }

    if issue.save
      process_attachments_and_comments(email, issue, author)
      { created: true }
    else
      log_issue_creation_failure(email[:subject], issue)
    end
  end

  def available_custom_fields_for_issue
    IssueCustomField.where(
      id: @job.tracker.custom_field_ids & @project.all_issue_custom_fields.pluck(:id)
    )
  end

  def process_attachments_and_comments(email, issue, author)
    add_attachments(email, issue, author)
    Rails.logger.info("Issue created for email: #{email[:subject]}")
    mark_email_as_read(email[:id])
    add_comments_for_issue(email, issue, author) if email[:children].any?
  end

  def issue_params(email, author)
    {
      subject: email[:subject],
      description: email[:body],
      status_id: 1, # Open status
      author_id: author.try(:id) || 1,
      tracker_id: @tracker,
      priority_id: @priority,
      assigned_to_id: @assigned_to,
      start_date: start_date_for_issue,
      email_message_id: email[:conversation_id],
    }
  end

  def start_date_for_issue
    User.current.today if Setting.default_issue_start_date_to_creation_date?
  end

  def build_custom_field_parameters(available_custom_fields)
    available_custom_fields.each_with_object({}) do |field, custom_field_values|
      custom_field_values[field.id.to_s] = determine_field_value(field)
    end
  end

  def determine_field_value(field)
    value = field.default_value.presence || default_value_for_field(field)
    apply_field_format_validations(field, value)
  end

  def default_value_for_field(field)
    case field.field_format
    when 'list' then field.possible_values&.last
    when 'date' then Date.today.to_s
    when 'int' then 0
    when 'float' then 0.0
    when 'string' then "DefaultValue"
    else nil
    end
  end

  def apply_field_format_validations(field, value)
    case field.field_format
    when 'int', 'float'
      value = validate_field_length(value, field)
    when 'string'
      value = validate_string_field(value, field)
    end
    value
  end

  def validate_field_length(value, field)
    value = value.to_i if field.field_format == 'int'
    value = value.to_f if field.field_format == 'float'
    value = adjust_length(value.to_s, field) if field.min_length || field.max_length
    value
  end

  def adjust_length(value, field)
    value = value.rjust(field.min_length, '1') if field.min_length && value.length < field.min_length
    value = value[0...field.max_length] if field.max_length && value.length > field.max_length
    value
  end

  def validate_string_field(value, field)
    value = value.ljust(field.min_length, '_') if field.min_length && value.length < field.min_length
    value = value[0...field.max_length] if field.max_length && value.length > field.max_length
    value = field.possible_values&.first || "DefaultValue" if field.regexp.present? && !Regexp.new(field.regexp).match?(value.to_s)
    value
  end

  def add_attachments(email, issue, user, journal_create = false)
    return unless email[:attachments]&.any?

    existing_attachments = issue.attachments.to_a
    email[:attachments].each do |attachment|
      attachment_content = Base64.decode64(attachment[:content])

      already_attached = existing_attachments.any? do |existing|
        existing.filename == attachment[:name] &&
          existing.content_type == attachment[:content_type] &&
          existing.filesize == attachment_content.bytesize
      end
      next if already_attached
      attachment_obj = issue.attachments.create(
        container: issue,
        file: attachment_content,
        filename: attachment[:name],
        author: user,
        content_type: attachment[:content_type]
      )

      if journal_create
        note = attachment[:name]
        journal = issue.journals.create(user: user, notes: note)
        JournalDetail.create(
          journal_id: journal.id,
          property: 'attachment',
          prop_key: attachment_obj.id,
          value: note
        )
      end
    end
  end

  def find_or_create_user_from_attributes(email_address, firstname = nil, lastname = nil)
    User.find_by_mail(email_address) || create_user(email_address, firstname, lastname)
  end

  def create_user(email_address, firstname, lastname)
    user = User.new(mail: email_address, login: email_address[0, User::LOGIN_LENGTH_LIMIT])
    user.firstname = (firstname.presence || "-")[0, 30]
    user.lastname = (lastname.presence || "-")[0, 30]
    user.language = Setting.default_language
    user.generate_password = true
    user.mail_notification = 'none'
    user.save!
    user
  end

  def add_comments_for_issue(email, parent_issue, user, execute_parent = false)
    return unless parent_issue

    if execute_parent
      create_comment_for_issue(parent_issue, email, user)
    end

    email[:children].each do |child_email|
      add_comments_for_issue(child_email, parent_issue, user, true)
      mark_email_as_read(child_email[:id])
    end
  end

  def create_comment_for_issue(issue, email, user)
    return if Journal.exists?(journalized_type: "Issue", journalized_id: issue.id, notes: email[:id])

    comment = "Reply to email: #{email[:subject]} - #{email[:body]}"
    issue.reload
    issue.notes = comment
    issue.journals.create(user: user, notes: comment)
    add_attachments(email, issue, user, true)
    issue.save!
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

  def group_emails_by_parent(emails)
    grouped_emails = emails.group_by { |email| email[:parent_id] }
    top_level_emails = grouped_emails[nil] || []

    result = top_level_emails.map do |parent_email|
      children = grouped_emails[parent_email[:id]] || []
      parent_email.merge(children: children.map { |child| child.merge(children: []) })
    end
    ungrouped_emails = emails.reject { |email| grouped_emails[email[:parent_id]] }
    result.concat(ungrouped_emails.map { |email| email.merge(children: []) })

    result
  end
end
