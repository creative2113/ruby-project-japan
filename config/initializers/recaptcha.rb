Recaptcha.configure do |config|
  config.site_key = Rails.application.credentials.google_recaptcha[:site_key]
  config.secret_key = Rails.application.credentials.google_recaptcha[:secret_key]
end
