class CreateMailJobSchedules < ActiveRecord::Migration[7.2]
  def change
    create_table :mail_job_schedules do |t|
      t.string  :email
      t.integer :project_id
      t.integer :tracker_id
      t.integer :assigned_to_id
      t.integer :priority_id
      t.string  :frequency
      t.boolean :active, default: true
      t.integer :sync_status, default: 0
      t.integer :last_sync_email_count, default: 0
      t.datetime :inbox_last_sync_at
      t.text :message
      t.timestamps
    end
    add_index :mail_job_schedules, :email, unique: true
    add_index :mail_job_schedules, :project_id
    add_index :mail_job_schedules, :tracker_id
    add_index :mail_job_schedules, :assigned_to_id
    add_index :mail_job_schedules, :priority_id
  end
end
