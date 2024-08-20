# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

env :PATH, ENV['PATH']

set :output, '/opt/GETCD/shared/log/crontab.log'
ENV['RAILS_ENV'] ||= 'development'
set :environment, ENV['RAILS_ENV']


if ENV['RAILS_ROLE'] == 'batch'
  every 1.minutes do
    runner "Tasks::WorkersHandler.execute"
    runner "CrawlTestWorker.execute" if ENV['RAILS_ENV'] == 'dev'
  end

  # 高確率でタイムアウト再起動が発生するので、定期実行は中止
  # every 3.hours do
  #   runner "Tasks::WorkersHandler.restart"
  # end

  every 1.day, at: '2:00 am' do
    runner "DeleteWorker.delete_results_files_working_dirs"
  end
end


if ENV['RAILS_ROLE'] == 'web'
  every 1.day, at: '4:00 am' do
    runner "BillingWorker.all_execute"
  end

  every 1.day, at: '3:00 am' do
    runner "DeleteWorker.delete_requests"
  end

  every 1.day, at: '3:30 am' do
    runner "DeleteWorker.delete_results"
  end

  every 1.day, at: '2:20 am' do
    runner "DeleteWorker.delete_tmp_results_files"
  end
end


every 1.minutes do
  runner "HealthCheckWorker.check"
end

every 7.day, at: '3:30 am' do
  command "sudo certbot renew && sudo systemctl restart nginx"
end

every 1.day, at: '2:20 am' do
  command 'sudo mv /opt/GETCD/current/log/crontab.log /opt/GETCD/current/log/crontab.log.`date --date "1 day ago" "+%Y%m%d"`'
end

#####  Clam AV を封印 START   ######
#
# every 3.hours do
#   command 'sudo /usr/bin/freshclam -u root'
# end

# every 1.day, at: '4:50 am' do
#   # it takes about within 1 minute.
#   command "sudo service clamd.scan restart"
# end

# every 1.day, at: '5:00 am' do
#   # it takes about 12 - 15 minutes.
#   command "sudo /usr/bin/clamdscan / --move=/home/admin/virus -l /home/admin/virus_check.log"
# end


# every 5.minutes do
#   runner "Tasks::VirusCheck.execute"
# end
#
#####  Clam AV を封印 END   ######

