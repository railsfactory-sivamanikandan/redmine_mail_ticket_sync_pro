namespace :microsoft_mail do
  desc "Fetch unread emails from Outlook"
  task :fetch_and_create_issues => :environment do
    project = ENV['project']
    email = ENV['email']
    if email.nil? || project.nil?
      puts "All parameters (email, project) are required."
      next
    end
    project = Project.find_by_identifier(project)
    if project
      mailbox = MailJobSchedule.find_by(project_id: project.id, email: email)
      if mailbox && mailbox.active
        args = {tracker: mailbox.tracker_id, priority: mailbox.priority_id, assigned_to: mailbox.assigned_to_id}
        mail_service = OutlookMailService.new(mailbox, args)
        mail_service.fetch_and_create_issues
      end
    end
  end
end
