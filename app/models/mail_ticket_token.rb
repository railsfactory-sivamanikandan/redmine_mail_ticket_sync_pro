class MailTicketToken < ApplicationRecord
  encrypts :access_token, :refresh_token
  belongs_to :mail_ticket_provider
  belongs_to :mail_job_schedule

  enum status: { created: 0, authenticated: 1, failed: 2 }

  # default_scope -> { where(active: true) }
end
