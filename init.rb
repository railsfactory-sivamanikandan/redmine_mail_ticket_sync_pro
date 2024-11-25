Redmine::Plugin.register :redmine_mail_ticket_sync_pro do
  name 'Redmine Mail Ticket Sync Pro plugin'
  author 'Sivamanikandan'
  description 'The MailTicketSyncPro plugin for Redmine enables seamless integration with email providers like Gmail and Outlook. It fetches emails from configured inboxes, creates Redmine issues automatically, and synchronizes email status by marking processed emails. With robust token management, customizable job schedules, and secure data encryption, the plugin simplifies task automation and enhances productivity in email-based workflows.'
  version '0.0.1'
  url 'https://github.com/railsfactory-sivamanikandan/redmine_mail_ticket_sync_pro.git'
  author_url 'https://github.com/railsfactory-sivamanikandan'

  menu :admin_menu, :mail_ticket_providers, { controller: 'admin/mail_ticket_providers', action: 'index' }, caption: 'Mail Providers', after: :plugins, html: { class: 'icon icon-email' }
  menu :admin_menu, :mail_job_schedules, { controller: 'admin/mail_job_schedules', action: 'index' }, caption: 'Email Sync Settings', after: :plugins, html: { class: 'icon icon-email' }
end
