namespace :maintenance do
  desc "maintenance start and open maintenance page"
  task :start, :finish_time, :ip do |task, args|
    on roles(:app) do
      puts args
      if args[:finish_time].nil? || args[:finish_time] == ''
        raise 'Argument :finish_time is essential!'
      end
      cmd = "cd /opt/GETCD/current && ~/.rbenv/shims/bundle exec bin/rails maintenance:start "
      cmd = cmd + "reason='メンテナンス中につき、ご迷惑をおかけしています。<br>終了時刻は#{args[:finish_time]}を予定しております。' "
      cmd = cmd + "allowed_paths='/sidekiq' allowed_ips='#{args[:ip]}' RAILS_ENV=#{fetch(:stage)}"
      execute cmd
    end
  end

  desc "maintenance end and close maintenance page"
  task :end do
    on roles(:app) do
      execute "cd /opt/GETCD/current && ~/.rbenv/shims/bundle exec bin/rails maintenance:end RAILS_ENV=#{fetch(:stage)}"
    end
  end
end