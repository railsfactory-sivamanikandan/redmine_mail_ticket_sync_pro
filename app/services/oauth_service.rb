class OauthService
  def self.fetch_emails_from_provider(provider, access_token)
    case provider
    when 'gmail'
      service = GmailService.new
      emails = service.fetch_inbox_emails(access_token)

      p "emailsemailsemailsemails"
      p emails
    when 'outlook'
      OutlookService.fetch_emails(access_token)
    else
      { error: 'Unsupported provider' }
    end
  end

  def self.get_authorize_url_for_provider(provider)
    case provider
    when 'gmail'
      service = GmailService.new
    when 'outlook'
      service = OutlookService.new
    else 
      { error: 'Unsupported provider' }
    end
    service.authorization_url
  end

  def self.get_access_token_for_provider(provider, code)
    case provider
    when 'gmail'
      service = GmailService.new
      service.get_access_token(code)
    when 'outlook'
      OutlookService.get_access_token(code)
    else
      { error: 'Unsupported provider' }
    end
  end
end
