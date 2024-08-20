require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module GETCD
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    #to auto load lib/ directory
    config.paths.add 'lib', eager_load: true

    config.active_job.queue_adapter = :sidekiq

    require "#{config.root}/lib/string"
    require "#{config.root}/lib/hash"
    require "#{config.root}/lib/array"
    require "#{config.root}/lib/secure_random"

    config.time_zone = 'Tokyo'
    config.active_record.default_timezone = :local

    config.i18n.default_locale = :ja
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
  end
end

# Virus Scan Clamd
# Clamd.configure do |config|
#   config.host = 'localhost'
#   config.port = 3310
#   config.open_timeout = 5
#   config.read_timeout = 20
#   config.chunk_size = 102400
# end
