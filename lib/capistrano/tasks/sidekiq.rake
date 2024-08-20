# bundle exec cap -T
namespace :sidekiq do
  desc "look status"
  task :status do
    on roles(:batch) do
      execute "cd /opt/GETCD/current && ~/.rbenv/shims/bundle exec bin/rails runner -e #{fetch(:stage)} Tasks::WorkersHandler.status"
    end
  end

  desc "sidekiq quiet"
  task :quiet2 do
    on roles(:batch) do
      execute "cd /opt/GETCD/current && ~/.rbenv/shims/bundle exec bin/rails runner -e #{fetch(:stage)} Tasks::WorkersHandler.quiet"
    end
  end

  desc "safe stop before deploy"
  task :safe_stop_before_deploy do
    on roles(:app) do
      execute "cd /opt/GETCD/current && ~/.rbenv/shims/bundle exec bin/rails runner -e #{fetch(:stage)} Tasks::WorkersHandler.stop_safely"
    end
  end

  desc "start after deploy"
  task :start_after_deploy do
    on roles(:app) do
      execute "cd /opt/GETCD/current && ~/.rbenv/shims/bundle exec bin/rails runner -e #{fetch(:stage)} Tasks::WorkersHandler.start_accept"
    end
  end
end
