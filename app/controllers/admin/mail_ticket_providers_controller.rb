class Admin::MailTicketProvidersController < ApplicationController
  before_action :find_mail_provider, only: %i[edit show update destroy]
  before_action :require_admin
  layout 'admin'


  def index
    @mail_providers = MailTicketProvider.all
  end

  def new
    @mail_provider = MailTicketProvider.new
  end

  def create
    @mail_provider = MailTicketProvider.new(mail_provider_params)

    if @mail_provider.save
      redirect_to admin_mail_ticket_providers_path, notice: 'Mail provider created successfully.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @mail_provider.update(mail_provider_params)
      redirect_to admin_mail_ticket_providers_path, notice: 'Mail provider updated successfully.'
    else
      render :edit
    end
  end

  def destroy
    if @mail_provider.destroy
      redirect_to admin_mail_ticket_providers_path, notice: 'Mail provider deleted successfully.'
    else
      redirect_to admin_mail_ticket_providers_path, notice: 'Mail provider deleted failed.'
    end
  end

  private

  def find_mail_provider
    @mail_provider = MailTicketProvider.find(params[:id])
  end

  def mail_provider_params
    defaults = { active: true }

    params.require(:mail_ticket_provider).permit(:client_id, :client_secret, :tenant_id, :callback_url, :name).reverse_merge(defaults)
  end
end
