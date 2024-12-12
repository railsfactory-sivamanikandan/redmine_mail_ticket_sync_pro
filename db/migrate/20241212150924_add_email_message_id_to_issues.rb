class AddEmailMessageIdToIssues < ActiveRecord::Migration[6.0]
  def change
    add_column :issues, :email_message_id, :string, null: true
  end
end