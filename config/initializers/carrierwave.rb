require 'carrierwave/storage/abstract'
require 'carrierwave/storage/file'
require 'carrierwave/storage/fog'

CarrierWave.configure do |config|
  keys = Rails.application.credentials.aws

  if Rails.env.production? || Rails.env.dev?
    config.storage :fog
    config.fog_provider = 'fog/aws'
    config.fog_directory = Rails.application.credentials.s3_bucket[:uploads]
    config.fog_public = false
    config.fog_credentials = {
      provider: 'AWS',
      aws_access_key_id: keys[:access_key_id],
      aws_secret_access_key: keys[:secret_access_key],
      region: 'ap-northeast-1',
      path_style: true,
    }
  else
    config.storage :file
    config.enable_processing = false if Rails.env.test?
    config.root = "#{Rails.root}/storage/uploads"
  end
end

CarrierWave::SanitizedFile.sanitize_regexp = /[^[:word:]\.\-\+]/
