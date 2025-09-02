Redmine::Plugin.register :redmine_mail_ticket_sync_pro do
  name 'Redmine Mail Ticket Sync Pro plugin'
  author 'Sivamanikandan'
  description 'The MailTicketSyncPro plugin for Redmine enables seamless integration with email providers like Gmail and Outlook. It fetches emails from configured inboxes, creates Redmine issues automatically, and synchronizes email status by marking processed emails. With robust token management, customizable job schedules, and secure data encryption, the plugin simplifies task automation and enhances productivity in email-based workflows.'
  version '0.0.1'
  url 'https://github.com/railsfactory-sivamanikandan/redmine_mail_ticket_sync_pro.git'
  author_url 'https://github.com/railsfactory-sivamanikandan'

  menu :admin_menu,
    :mail_ticket_providers,
    { controller: 'admin/mail_ticket_providers', action: 'index' },
    caption: %Q{
      <svg xmlns="http://www.w3.org/2000/svg"
        class='s18 icon-svg' fill="currentColor"
        viewBox="0 0 24 24" style="vertical-align:middle;margin-right:4px;">
        <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0
                1.1.9 2 2 2h16c1.1 0 2-.9
                2-2V6c0-1.1-.9-2-2-2zm0
                4-8 5-8-5V6l8 5 8-5v2z"/>
      </svg>
      Mail Providers
    }.html_safe,
    after: :plugins,
    html: { class: 'icon' }
  menu :admin_menu,
    :mail_job_schedules,
    { controller: 'admin/mail_job_schedules', action: 'index' },
    caption: %Q{
      <svg xmlns="http://www.w3.org/2000/svg"
          class='s18 icon-svg' viewBox="0 0 24 24"
          fill="none" stroke="currentColor" stroke-width="2"
          stroke-linecap="round" stroke-linejoin="round"
          style="vertical-align:middle; margin-right:4px;">
        <rect x="2" y="4" width="20" height="16" rx="2" ry="2"></rect>
        <polyline points="22,6 12,13 2,6"></polyline>
        <circle cx="18" cy="18" r="4"></circle>
        <polyline points="18 16 18 18 20 18"></polyline>
      </svg>
      Email Sync Jobs
    }.html_safe,
    after: :plugins,
    html: { class: 'icon' }
end
