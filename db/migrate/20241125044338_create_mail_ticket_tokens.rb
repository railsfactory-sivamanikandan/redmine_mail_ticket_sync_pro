class CreateMailTicketTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :mail_ticket_tokens do |t|
      t.integer :mail_ticket_provider_id
      t.integer :mail_job_schedule_id
      t.text    :access_token
      t.text    :refresh_access_token
      t.integer :status, default: 0
      t.datetime :expires_at
      t.text :message
      t.timestamps
    end
    add_index :mail_ticket_tokens, :mail_ticket_provider_id
    add_index :mail_ticket_tokens, :mail_job_schedule_id
  end
end
