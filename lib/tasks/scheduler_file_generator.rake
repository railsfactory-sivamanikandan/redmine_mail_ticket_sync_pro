namespace :scheduler do
  desc "Fetch unread emails from Gmail and Outlook and process them"
  task :update_schedule => :environment do
    SchedulerFileGenerator.update_schedule
  end
end
