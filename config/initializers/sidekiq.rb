Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:6379' }
  config.redis = { db: 1 }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379' }
  config.redis = { db: 1 }
end
