keys = Rails.application.credentials.aws

creds = Aws::Credentials.new(keys[:access_key_id], keys[:secret_access_key])
Aws::Rails.add_action_mailer_delivery_method(:aws_sdk, credentials: creds, region: 'ap-northeast-1')

Aws.config.update({
  region: 'ap-northeast-1',
  credentials: creds,
  log_level: :info
})