Turnout.configure do |config|
  config.named_maintenance_file_paths = { app: ENV['MAINTENANCE_FILE_PATH'] }
end
