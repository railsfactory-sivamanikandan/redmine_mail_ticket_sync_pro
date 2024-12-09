class OauthService
  PROVIDERS = {
    'gmail' => GmailService,
    'outlook' => OutlookService
  }.freeze

  def self.get_authorize_url_for_provider(provider)
    service(provider)&.authorization_url
  end

  def self.get_access_token_for_provider(provider, code)
    service(provider)&.get_access_token(code)
  end

  private

  def self.service(provider)
    PROVIDERS[provider]&.new
  end
end
