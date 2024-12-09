class MailTicketProvider < ApplicationRecord
  encrypts :client_id, :client_secret, :tenant_id
  has_many :mail_ticket_tokens, dependent: :destroy

  default_scope -> { where(active: true) }
  delegate :provider_name, to: :mail_ticket_tokens
  validates :name, presence: true, uniqueness: true
  validates :client_id, :client_secret, :callback_url, presence: true
  validates :tenant_id, presence: true, if: -> { name == 'outlook' }
end
