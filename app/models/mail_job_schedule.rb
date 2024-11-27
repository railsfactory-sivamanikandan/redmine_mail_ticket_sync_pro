class MailJobSchedule < ApplicationRecord
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  has_one :mail_ticket_token, dependent: :destroy
  belongs_to :mail_ticket_provider
  belongs_to :project
  belongs_to :tracker
  belongs_to :assigned_to, class_name: 'User'
  belongs_to :priority
  accepts_nested_attributes_for :mail_ticket_token
  delegate :access_token, :expires_at, :refresh_token, to: :mail_ticket_token
  validates :project_id, :priority_id, :assigned_to_id, :tracker_id, presence: true
  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX, message: 'is invalid' }, uniqueness: { case_sensitive: false }  
  enum sync_status: { not_synced: 0, syncing: 1, synced: 2 }
  default_scope -> { where(active: true) }
  after_commit :generate_schedule_file, unless: :new_or_specific_column_changed?


  def provider_name
    mail_ticket_token&.mail_ticket_provider&.name&.capitalize
  end

  def is_account_verified?
    mail_ticket_token&.access_token.present?
  end

  private

  def new_or_specific_column_changed?
    (saved_change_to_last_sync_email_count? || saved_change_to_sync_status? || saved_change_to_last_sync_email_count? || saved_change_to_message?)
  end

  def generate_schedule_file
    SchedulerFileGenerator.update_schedule if mail_ticket_token.access_token
  end
end
