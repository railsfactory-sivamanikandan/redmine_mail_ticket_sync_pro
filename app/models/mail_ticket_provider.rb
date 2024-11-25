class MailTicketProvider < ApplicationRecord
  encrypts :client_id, :client_secret, :tenant_id
  has_many :mail_ticket_tokens, dependent: :destroy

  default_scope -> { where(active: true) }
  delegate :provider_name, to: :mail_ticket_tokens
  validates :client_id, :client_secret, :tenant_id, :callback_url, :name, presence: true
end
