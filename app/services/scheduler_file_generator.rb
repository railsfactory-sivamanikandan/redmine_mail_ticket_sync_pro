class SchedulerFileGenerator
  SCHEDULE_FILE_PATH = Rails.root.join('config', 'schedule.rb').freeze

  # Entry point to update the schedule
  def self.update_schedule
    new.generate_schedule
  end

  # Generate the schedule file
  def generate_schedule
    jobs = MailJobSchedule.joins(:mail_ticket_token).where.not(mail_ticket_tokens: {access_token: [nil, ""]})
    File.open(SCHEDULE_FILE_PATH, 'w') do |file|
      write_file_header(file)
      jobs.each do |mailbox|
        write_job_entry(file, mailbox)
      end
    end

    reload_whenever_schedule
  end

  private

  # Write the file header
  def write_file_header(file)
    file.puts "# Generated schedule file"
    file.puts "# Last updated: #{Time.current}"
    file.puts
  end

  # Write individual job entry for a mailbox
  def write_job_entry(file, mailbox)
    frequency = mailbox.frequency || '30.minutes'
    project_identifier = mailbox.project&.identifier || 'default_project'
    email = mailbox.email || 'default_email@example.com'
    environment = Rails.env
    log_file = "/app/log/#{project_identifier}_#{email.parameterize}.log"
    file.puts "every #{frequency} do"
    file.puts "  set :output, \"#{log_file}\""
    file.puts "  rake \"emails:fetch_and_create_issues project=#{project_identifier} email=#{email}\", environment: \"#{environment}\""
    file.puts "end"
    file.puts
  end

  # Reload the whenever configuration to apply changes
  def reload_whenever_schedule
    system('whenever --update-crontab')
  end
end