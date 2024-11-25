class CreateMailTicketProviders < ActiveRecord::Migration[7.2]
  def change
    create_table :mail_ticket_providers do |t|
      t.integer :user_id
      t.string  :name
      t.string  :client_id
      t.string  :client_secret
      t.string  :tenant_id
      t.boolean :active, default: false
      t.string  :callback_url
      t.timestamps
    end
    add_index :mail_ticket_providers, :user_id
  end
end
