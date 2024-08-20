class HealthCheckWorker

  class << self

    def check
      GC.start

      return true if Sidekiqer.new.deploying_now?

      check_nginx
      check_puma

      check_sidekiq_rebooting_cntl_file if ENV['RAILS_ROLE'] == 'batch'
      check_active_sidekiq_request if ENV['RAILS_ROLE'] == 'batch'
      check_active_sidekiq_result if ENV['RAILS_ROLE'] == 'batch'
      check_server_reboot_cntl_file

      # Disk容量のチェック
      size_short = check_disk_size

      # メモリ容量をチェック
      mem_short = check_memory

      # サーバがアクセス反応があるかチェック
      return unless check_response(mem_short, size_short)

      if mem_short.present? && ( mem_ave = Memory.average(count: 3, interval: 8) ) < memory_threshold
        deliver(NoticeMailer.notice_simple("メモリー不足 平均 #{mem_ave}M\nALL #{Memory.all}", 'メモリー不足 ヘルスチェック check', "【#{ENV['RAILS_ROLE'] }】バッチ"))
      end

      if size_short.present?
        deliver(NoticeMailer.notice_simple(size_short, '空き容量不足 ヘルスチェック check', "【#{ENV['RAILS_ROLE'] }】バッチ"))
      end

      check_quiet_sidekiq
      check_stop_sidekiq

    rescue => e
      Lograge.job_logging('Workers', 'error', 'HealthCeckWorker', 'check', { issue: 'Health Check Error', err_msg: e.message, backtrace: e.backtrace})
    end

    def memory_threshold
      if ENV['RAILS_ROLE'] == 'batch'
        800
      else
        800
      end
    end

    def nginx_redis_key
      'nginx_count'
    end

    # nginxのプロセス設定 => /etc/nginx/nginx.conf
    def nginx_process_count
      1
    end

    def check_nginx
      stdout, stderr, status = Open3.capture3('ps aux | grep nginx')
      unless status.success?
        deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [ps aux | grep nginx]\n\n" + stderr, 'ヘルスチェック check grep nginx', "【#{ENV['RAILS_ROLE'] }】バッチ"))
        return false
      end

      cnt = 0
      stdout.split("\n").each do |txt|
        cnt += 1 if txt.start_with?('nginx ') && txt.end_with?('nginx: worker process')
      end

      if cnt < nginx_process_count
        count = get_redis_count(nginx_redis_key)
        return set_redis(nginx_redis_key, count) if count < 3

        stdout, stderr, status = Open3.capture3('sudo systemctl restart nginx')
        unless status.success?
          deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [sudo systemctl restart nginx]\n\n" + stderr, 'ヘルスチェック check restart nginx', "【#{ENV['RAILS_ROLE'] }】バッチ"))
          return false
        else
          deliver(NoticeMailer.notice_simple("nginx 再起動", 'ヘルスチェック nginx 再起動', "【#{ENV['RAILS_ROLE'] }】バッチ"))
        end

        set_redis(nginx_redis_key, 0)
      end
    end

    def puma_redis_key
      'puma_count'
    end

    def puma_process_count
      2
    end

    def check_puma
      stdout, stderr, status = Open3.capture3('ps aux | grep puma')
      unless status.success?
        deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [ps aux | grep puma]\n\n" + stderr, 'ヘルスチェック check grep puma', "【#{ENV['RAILS_ROLE'] }】バッチ"))
        return false
      end

      cnt = 0
      stdout.split("\n").each do |txt|
        cnt += 1 if txt.include?(' puma: cluster worker ')
      end

      if cnt < puma_process_count
        count = get_redis_count(puma_redis_key)
        return set_redis(puma_redis_key, count) if count < 3

        stdout, stderr, status = Open3.capture3('sudo systemctl restart puma')
        unless status.success?
          deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [sudo systemctl restart puma]\n\n" + stderr, 'ヘルスチェック check restart puma', "【#{ENV['RAILS_ROLE'] }】バッチ"))
          return false
        else
          deliver(NoticeMailer.notice_simple("puma 再起動", 'ヘルスチェック puma 再起動', "【#{ENV['RAILS_ROLE'] }】バッチ"))
        end

        set_redis(puma_redis_key, 0)
      end
    end

    def sidekiq_rebooting_redis_key
      'sidekiq_rebooting_count'
    end

    def check_sidekiq_rebooting_cntl_file
      return true if Sidekiqer.new.deploying_now?

      count = get_redis_count(sidekiq_rebooting_redis_key)
      unless Sidekiqer.new.rebooting_now?
        set_redis(sidekiq_rebooting_redis_key, 0) if count > 1
        return
      end

      if ( Server.new.rebooted? && count > 5 ) || count > 70
        deliver(NoticeMailer.notice_simple("Sidekiq Rebootingファイル 削除", 'ヘルスチェック Sidekiq Rebootingファイル 削除', "【#{ENV['RAILS_ROLE'] }】バッチ"))
        Sidekiqer.new.remove_reboot_control_file
        count = 0
      elsif count % 5 == 0
        deliver(NoticeMailer.notice_simple("Sidekiq Rebooting Now", 'ヘルスチェック Sidekiq Rebooting Now', "【#{ENV['RAILS_ROLE'] }】バッチ"))
      end

      set_redis(sidekiq_rebooting_redis_key, count)
    end

    def check_server_reboot_cntl_file
      Server.new.remove_reboot_control_file
    end

    def check_active_sidekiq_request
      return if Sidekiqer.new.rebooting_now?
      return if Sidekiqer.new.active_process?(['request', 'test_request', 'arrange'])

      sleep 20
      unless Sidekiqer.new.active_process?(['request', 'test_request', 'arrange'])

        stdout, stderr, status = Open3.capture3('sudo systemctl restart sidekiq')
        unless status.success?
          deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [sudo systemctl restart sidekiq]\n\n" + stderr, 'ヘルスチェック check restart sidekiq', "【#{ENV['RAILS_ROLE'] }】バッチ"))
          return false
        else
          deliver(NoticeMailer.notice_simple("sidekiq_requestプロセス 起動", 'ヘルスチェック sidekiq_requestプロセス 起動', "【#{ENV['RAILS_ROLE'] }】バッチ"))
        end
      end
    end

    def check_active_sidekiq_result
      return if Sidekiqer.new.active_process?(['make_result'])

      sleep 20
      unless Sidekiqer.new.active_process?(['make_result'])

        stdout, stderr, status = Open3.capture3('sudo systemctl restart sidekiq_result')
        unless status.success?
          deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [sudo systemctl restart sidekiq_result]\n\n" + stderr, 'ヘルスチェック check restart sidekiq_result', "【#{ENV['RAILS_ROLE'] }】バッチ"))
          return false
        else
          deliver(NoticeMailer.notice_simple("sidekiq_resultプロセス 起動", 'ヘルスチェック sidekiq_resultプロセス 起動', "【#{ENV['RAILS_ROLE'] }】バッチ"))
        end
      end
    end

    def check_disk_size
      size_short = ''
      stdout, stderr, status = Open3.capture3('df')
      unless status.success?
        deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [df]\n\n" + stderr, 'ヘルスチェック check', "【#{ENV['RAILS_ROLE'] }】バッチ"))
      else
        size_rate = stdout.split("\n").delete_if {|str| !str.start_with?('/dev/nvme0n1p1') }[0].split(' ')[4].to_i

        if size_rate > 95
          size_short = "空き容量不足 現在 #{size_rate}%"
          stdout, stderr, status = Open3.capture3('sudo rm -rf /tmp/.org.chromium.Chromium*')
          deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [sudo rm -rf /tmp/.org.chromium.Chromium*]\n\n" + stderr, 'ヘルスチェック check', "【#{ENV['RAILS_ROLE'] }】バッチ")) unless status.success?
          stdout, stderr, status = Open3.capture3('sudo  find /var/log/ -type f -name \* -exec cp -f /dev/null {} \;')
          deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [sudo  find /var/log/ -type f -name \\* -exec cp -f /dev/null {} \\;]\n\n" + stderr, 'ヘルスチェック check', "【#{ENV['RAILS_ROLE'] }】バッチ")) unless status.success?
        end
      end
      size_short
    end

    def check_memory
      mem_short = ''
      if Memory.current < memory_threshold && ( mem_ave = Memory.average(count: 5, interval: 3) ) < memory_threshold
        check_memory_short_count if ENV['RAILS_ROLE'] == 'batch'
        mem_short = "メモリー不足 平均 #{mem_ave}M\nALL #{Memory.all}"
      end
      mem_short
    end

    def check_memory_short_count
      return unless ENV['RAILS_ROLE'] == 'batch'

      count = get_redis_count(memory_redis_key)

      if count > 4

        set_redis(memory_redis_key, -20)

        times = Rediser.new.get_times(sidekiq_reboot_redis_key)

        if ( Sidekiq::Workers.new.size == 0 &&
             Sidekiq::Queue.new.size == 0 &&
             Sidekiqer.new.get_working_request_ids.values.all_blank? ) ||
           ( times.size >= 2 && times[0] > Time.zone.now - 45.minutes )

          Rediser.new.reset_times(sidekiq_reboot_redis_key)
          Server.new('[HealthCheckWorker]').reboot(log: MyLog.new('my_crontab'))
        end

        Rediser.new.set_times(sidekiq_reboot_redis_key)

        # メモリ不足の原因は クローラ
        Sidekiqer.new('[HealthCheckWorker]').recovery_memory(log: MyLog.new('my_crontab'))

        count = 0
      end

      set_redis(memory_redis_key, count)
    end

    def sidekiq_reboot_redis_key
      'sidekiq_reboot_redis_key'
    end

    def memory_redis_key
      'memory_short_count'
    end

    def check_response(memory_message, size_message)
      return true if Sidekiqer.new.deploying_now?

      url = "https://#{EasySettings.service_host}/"

      urls = if Rails.env.dev?
        [url, url.gsub('', '')]
      elsif Rails.env.production?
        [url, url.gsub('https://', 'https://batch.')]
      end

      err_flg = false
      urls.each do |url|
        role = url.include?('batch') ? 'BATCH' : 'WEB'
        begin
          # res = Url.get_response_with_timeout(url, 8) # 502 Bad GateWayはOKになる
          res = Crawler::ScrapingAlchemist.new(url)
        rescue => e
          res = "err_class: #{e.class}, err_msg: #{e.message}"
          deliver(NoticeMailer.notice_simple("アクセスの反応なし #{res}\n#{memory_message}\n#{size_message}", "#{role} アクセス反応なし ヘルスチェック check", "【#{ENV['RAILS_ROLE'] }】バッチ"))
          err_flg = true
        end

        if res.class == Crawler::ScrapingAlchemist &&
           ( res.status != :success || !res.doc.text.include?(EasySettings.service_name) )
          text = res.doc.class == String ? '' : res.doc.text
          deliver(NoticeMailer.notice_simple("アクセスの反応なし #{res.status}\n#{text}\n#{memory_message}\n#{size_message}", "#{role} アクセス反応なし ヘルスチェック check", "【#{ENV['RAILS_ROLE'] }】バッチ"))
          err_flg = true
        end
      end

      !err_flg
    end

    def check_quiet_sidekiq
      if ( res = Sidekiqer.new.get_quiet_process ).present? && ( !Sidekiqer.new.deploying_now? && !Sidekiqer.new.rebooting_now? )
        res.delete_if { |q| q.include?('request') } if Sidekiqer.new.rebooting_now?

        deliver(NoticeMailer.notice_simple("Sidekiqで QUIETプロセスあり\n#{res.join("\n")}", 'QUIETプロセス ヘルスチェック check', "【#{ENV['RAILS_ROLE'] }】バッチ"))
      end
    end

    def check_stop_sidekiq
      total_queue = Sidekiq::Queue.new(:default).count + Sidekiq::Queue.new(:mailer).count + Sidekiq::Queue.new(:request).count + Sidekiq::Queue.new(:search).count

      redis = Redis.new
      res = redis.get(redis_key)
      queue_size, count = res.blank? ? [-1, 0] : res.split(' ')


      if total_queue > 0 && queue_size.to_i == total_queue
        count = count.to_i + 1
      else
        count = 0
      end

      if count > 5
        deliver(NoticeMailer.notice_simple('サイドキックが止まっている可能性あり', 'サイドキック停止 ヘルスチェック check', "【#{ENV['RAILS_ROLE'] }】バッチ"))
      end

      set_redis(redis_key, "#{total_queue} #{count}")
    end

    def set_redis(key, value)
      Rediser.new.set_count(key, value)
    end

    def get_redis_count(key)
      Rediser.new.get_count(key)
    end

    def deliver(mailer_instance)
      cnt ||= 0
      mailer_instance.deliver_now
    rescue => e
      cnt += 1
      sleep 2
      retry if cnt < 6
    end

    def redis_key
      'sidekiq_queue_count'
    end
  end
end
