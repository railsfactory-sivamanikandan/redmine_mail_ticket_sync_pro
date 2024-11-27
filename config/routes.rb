RedmineApp::Application.routes.draw do
  namespace :admin do
    resources :mail_ticket_providers
    resources :mail_job_schedules
  end

  match '/admin/mail_job_schedules/start_mail_sync/:id', to: 'admin/mail_job_schedules#start_mail_sync', as: 'start_mail_sync', via: [:get]
  match '/auth/:provider/oauth', to: 'admin/mail_job_schedules#login', as: 'provider_login', via: [:get, :post]
  match '/auth/callback/:provider', to: 'admin/mail_job_schedules#callback', as: 'provider_callback', via: [:get, :post]
end