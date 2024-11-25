class Admin::MailJobSchedulesController < ApplicationController
  before_action :find_mail_job_schedule, only: %i[edit update destroy, start_mail_sync]
  before_action :require_admin
  layout 'admin'

  def index
    @jobs = MailJobSchedule.all
  end

  def new
    @mail_job_schedule = MailJobSchedule.new
    @mail_job_schedule.build_mail_ticket_token 
    @projects = Project.all
    @trackers = Tracker.all
    @users = User.all
    @priorities = IssuePriority.all
    @providers = MailTicketProvider.all
  end

  def create
    @mail_job_schedule = MailJobSchedule.new(mail_job_schedule_params)

    if @mail_job_schedule.save
      redirect_to admin_mail_job_schedules_path, notice: 'Mail Job Schedule created successfully.'
    else
      @projects = Project.all
      @trackers = Tracker.all
      @users = User.all
      @priorities = IssuePriority.all
      @providers = MailTicketProvider.all
      render :new
    end
  end

  def edit
    @mail_job_schedule.build_mail_ticket_token if @mail_job_schedule.mail_ticket_token.nil?
    @projects = Project.all
    @trackers = Tracker.all
    @users = User.all
    @priorities = IssuePriority.all
    @providers = MailTicketProvider.all
  end

  def update
    if @mail_job_schedule.update(mail_job_schedule_params)
      redirect_to admin_mail_job_schedules_path, notice: 'Mail Job Schedule updated successfully.'
    else
      @projects = Project.all
      @trackers = Tracker.all
      @users = User.all
      @priorities = IssuePriority.all
      @providers = MailTicketProvider.all
      render :edit
    end
  end

  def destroy
    if @mail_job_schedule.destroy
      redirect_to admin_mail_job_schedules_path, notice: 'Mail Job Schedule deleted successfully.'
    end
  end

  def login
    service = OutlookOauthService.new
    redirect_to service.authorization_url('user.read mail.readwrite offline_access')
  end

  def callback
    service = OutlookOauthService.new
    token_data = service.fetch_token(params[:code])
    if token_data
      update_outlook_configuration(token_data)
      flash[:notice] = "Logged in successfully! Email: #{token_data[:email]}"
    else
      flash[:error] = l(:error_oauth_failed)
    end
    redirect_to admin_mail_job_schedules_path, notice: 'Mail provider successfully authenticated.'
	end

  def start_mail_sync
    if @mail_job_schedule.is_account_verified?
      @mail_job_schedule.update(sync_status: 1)
      args = {tracker: @mail_job_schedule.tracker_id, priority: @mail_job_schedule.priority_id, assigned_to: @mail_job_schedule.assigned_to_id}
      mail_service = OutlookMailService.new(@mail_job_schedule, args)
      mail_service.fetch_and_create_issues
    end
    redirect_to admin_mail_job_schedules_path, notice: 'Mail sync successfully.'
  end

  private

  def find_mail_job_schedule
    @mail_job_schedule = MailJobSchedule.find(params[:id])
  end

  def mail_job_schedule_params
    params.require(:mail_job_schedule).permit(:project_id, :assigned_to_id, :email, 
      :tracker_id, :priority_id, :frequency, mail_ticket_token_attributes: [:id, :mail_ticket_provider_id] )
  end

  def update_outlook_configuration(token_data)
    job = MailJobSchedule.find_by(email: token_data[:email])
    job.update(
      sync_status: 0, 
      last_sync_email_count: 0, 
      inbox_last_sync_at: nil
    )
    mail_ticket_token = job.mail_ticket_token
    mail_ticket_token.update(
      access_token: token_data[:access_token],
      refresh_access_token: token_data[:refresh_token],
      expires_at: token_data[:expires_at],
      status: 1,
    )
  end
end
