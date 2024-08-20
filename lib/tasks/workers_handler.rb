require 'sidekiq/api'
require "open3"

class Tasks::WorkersHandler

  class << self

    def status
      puts "[#status] START"

      puts "[#status] PROCESS COUNT=#{Sidekiq::ProcessSet.new.size}"
      Sidekiq::ProcessSet.new.each do |sq|
        puts "[#status] ATTR=#{Sidekiq::ProcessSet.new.first.to_json}"
        puts "[#status] PROCESS PID=#{JSON.parse(sq.to_json)['attribs']['pid']}"
      end
      puts "[#status] WORKER SIZE=#{Sidekiq::Workers.new.size}"

      puts "[#status] QUEUE SIZE=#{Sidekiq::Queue.new.size} ( MAILER: #{Sidekiq::Queue.new(:mailers).size} )"

      puts "[#status] RETRY QUEUE SIZE=#{Sidekiq::RetrySet.new.size}"

      puts "[#status] END"
    end

    def quiet
      puts "[#quiet] START"

      puts "[#quiet] QUIET=#{Sidekiq::ProcessSet.new.each(&:quiet!)}"

      puts "[#quiet] END"
    end

    # デプロイ処理のために停止する
    def stop_safely
      puts "[#stop_safely] START"


      # その他の再起動の処理が動いてる時は、終わるまで待つ
      path = "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:sidekiq_reboot]}"
      300.times do |i| # 15分待機
        break unless File.exist?(path)
        sleep 3
      end

      if File.exist?(path)
        puts "[#stop_safely] その他のSidekiqが再起動が実行中です。15分経ちましたが、終わりません。確認した方がいいかもしれません。. #{path}"
        return
      end



      # /home/admin/contol/deployingファイルを作成する。このファイルがある時はサイドキックを停止し、再起動する
      # また、新規リクエストの受け入れを停止する
      # 毎分のexecuteの実行を無効化する
      path = "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:deploying]}"
      if File.exist?(path)
        puts "[#stop_safely] Already File exists. #{path}"
        return
      end

      FileUtils.touch(path)

      if ENV['RAILS_ROLE'] == 'web'
        puts "[#stop_safely] END"
        return
      end


      # メール以外のリクエストを削除する
      # メールはやり切る
      # サーチも止める。メンテ時間と被ったのが不運。
      # エクセル作成 => キューに入ってれば、削除しても、後から実行されるので削除！途中のものはやり切る
      Sidekiq::Queue.new(:request).clear
      Sidekiq::Queue.new(:test_request).clear
      Sidekiq::Queue.new(:search).clear
      Sidekiq::Queue.new(:make_result).clear
      puts "[#stop_safely] Clear queue"


      kiquer = Sidekiqer.new('[#stop_safely]')


      start = Time.now
      unless kiquer.wait_current_exec_jobs(until_cmplete_queue: true)
        puts "[#stop_safely] ERROR endless job"
        return
      end
      puts "[#stop_safely] Finish JOB. duration: #{Time.now - start}"


      # sidekiq:quiet
      # 新しいジョブを実行しなくなる。キューに貯まる
      kiquer.all_quiet!
      puts "[#stop_safely] quiet sidekiq"


      start = Time.now
      unless kiquer.wait_current_exec_jobs(until_cmplete_queue: true)
        puts "[#stop_safely] ERROR endless job"
        return
      end
      puts "[#stop_safely] Finish JOB. duration: #{Time.now - start}"
      sleep 1


      # リトライキューの処理
      # 　　メールのリトライは考えにくい。エラーになった原因も不明。→ 捨てる
      # 　　サーチ、テストリクエスト、エクセル作成のリトライはしない
      # 　　リクエストのリトライはある -> waitingに変更する
      Sidekiq::RetrySet.new.each do |retry_set|
        next unless retry_set.item['queue'] == 'request'
        req_url_id = retry_set.item['args'][0].to_i
        RequestedUrl.find(req_url_id).update!(status: EasySettings.status[:waiting])
      end
      Sidekiq::RetrySet.new.clear
      puts "[#stop_safely] Clear retry queue"
      sleep 1


      kiquer.stop_sidekiq!('sidekiq')
      # kiquer.stop_sidekiq!('sidekiq_mailer')
      kiquer.stop_sidekiq!('sidekiq_result')

      kiquer = nil

      stdout, stderr, status = Open3.capture3("sudo systemctl stop sidekiq_mailer")
      unless status.success?
        puts "[#stop_safely] ERROR stop sidekiq_mailer. err: #{stderr}"
        return
      end

      puts "[#stop_safely] sidekiq stoped safely"

      puts "[#stop_safely] END"
    end

    # デプロイ完了後のスタート
    def start_accept
      puts "[#start_accept] START"

      # /opt/sidekiq/deployingファイルを削除する
      path = "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:deploying]}"
      unless File.exist?(path)
        puts "[#start_accept] Already File deleted. #{path}"
        return
      end

      # 以下、デプロイを走らせなければ、再実行されないため
      if ENV['RAILS_ROLE'] == 'batch'
        stdout, stderr, status = Open3.capture3("sudo systemctl restart sidekiq")
        unless status.success?
          puts "[#start_accept] ERROR start sidekiq. err: #{stderr}"
          return
        end
      end

      stdout, stderr, status = Open3.capture3("sudo systemctl restart sidekiq_mailer")
      unless status.success?
        puts "[#start_accept] ERROR start sidekiq_mailer. err: #{stderr}"
        return
      end

      FileUtils.rm_f(path)
      puts "[#start_accept] END"
    end

    # sidekiqの再起動
    def restart
      cron_log = MyLog.new('my_crontab')

      kiqer = Sidekiqer.new('[Tasks::WorkersHandler][#restart]')

      kiqer.reboot_request_sidekiq(log: cron_log, reason: 'タスクにより再実行')

    rescue => e
      Lograge.job_logging('Tasks', 'error', 'Tasks::WorkersHandler', 'restart', {error: e, err_msg: e.message, backtrace: e.backtrace})

      NoticeMailer.deliver_later(NoticeMailer.notice_simple("異常終了\n" + kiqer.log.join("\n"), '異常終了。sidekiqの再起動バッチ restart', 'バッチ'))
    end

    # 1分間に1回、Queueを投げる
    # 5並列で10分で100リクエストを裁く想定（1リクエスト30sec）
    def execute(exe_request_num = 5, search_url_num = 10, max_queue: 100, stop_queue: 80, user_ids: nil, test_log: nil)
      cron_log = MyLog.new('my_crontab')
      logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] START"

      if Rails.env.dev?
        email = "abcdef#{Rails.application.credentials.user[:admin][:email]}"
        user = User.find_by_email(email)
        if Request.where(user: user).unfinished.present? && user_ids != [user.id]
          unless Random.rand(6) == 0
            logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] END BY CRAWL TEST"
            return :end_by_crawl_test
          end
          max_queue = 15
        end
      end

      mem = Memory.current
      if mem < 500 && Memory.average(count: 5, interval: 3) < 600
        logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] TOO INSUFFICIENT MEMORY AND END"
        Sidekiq::Queue.new(:request).clear
        Sidekiq::Queue.new(:test_request).clear
        GC.start
        return :too_insufficient_memory
      end

      if mem < 1000 && Memory.average(count: 5, interval: 3) < 800
        logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] INSUFFICIENT MEMORY AND END"
        GC.start
        return :insufficient_memory
      end

      if File.exist?("#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:sidekiq_reboot]}")
        logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] REBOOTING NOW AND END"
        return :rebooting
      end

      if File.exist?("#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:deploying]}")
        logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] DEPLOYING NOW AND END"
        return :deploying
      end

      # 前回のプロセスがまだ動いているかチェックする
      if working_self_process?('execute', test_log)
        logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] WORKING LAST PROCESS NOW AND END"
        return :working_last_process
      end

      # sidekiqの情報が取得できるか確認のための実行。もし、うまくいっていなければ、メールが飛ぶ。
      Sidekiqer.new.get_working_request_ids

      if Sidekiq::Queue.new(:request).size == 0
        RequestedUrl.waiting.each do |requested_url|
          RequestSearchWorker.perform_async(requested_url.id, requested_url.type, requested_url.url)
        end
      end


      sidekiqer = Sidekiqer.new

      # 結果ファイル作成ジョブの漏れを実行する
      restart_lost_result_file_jobs(sidekiqer)

      # アレンジ漏れを実行する
      restart_lost_arrange_jobs(sidekiqer)

      # もし、テストで実行漏れのものがあれば実行する
      restart_lost_test_request_jobs(sidekiqer)


      # all_workingの処理
      Request.all_working.each do |req|
        req.set_working if req.requested_urls.status_new.size > 0
      end

      # リトライ漏れの処理
      RequestedUrl.main.retry.where('updated_at < ?', Time.zone.now - 10.minutes).each do |requested_url|
        next if sidekiqer.get_retry_request_ids.include?(requested_url.id)
        next if sidekiqer.get_waiting_request_ids.include?(requested_url.id)
        next if sidekiqer.get_working_request_ids[:requested_urls].include?(requested_url.id)
        requested_url.update!(status: EasySettings.status.waiting)
        RequestSearchWorker.perform_async(requested_url.id, requested_url.type, requested_url.url)
      end

      # waiting
      RequestedUrl.main.waiting.where('updated_at < ?', Time.zone.now - 2.hours).each do |requested_url|
        next if sidekiqer.get_waiting_request_ids.include?(requested_url.id)
        next if sidekiqer.get_working_request_ids[:requested_urls].include?(requested_url.id)
        requested_url.update!(updated_at: Time.zone.now)
        RequestSearchWorker.perform_async(requested_url.id, requested_url.type, requested_url.url)
      end

      # working
      RequestedUrl.main.working.where('updated_at < ?', Time.zone.now - 20.minutes).each do |requested_url|
        next if sidekiqer.get_working_request_ids[:requested_urls].include?(requested_url.id)
        requested_url.update!(status: EasySettings.status.waiting)
        RequestSearchWorker.perform_async(requested_url.id, requested_url.type, requested_url.url)
      end


      # タイムアウト処理
      if Sidekiqer.new('[JOB TIMEOUT STOP]').timeout_job_stop!(timeout_min: 15, log: cron_log)
        logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] STOPED TIMEOUT JOBS AND END"
        return :stop_timeout_jobs
      end


      # Queueの数がmaxを超えていたら、スキップ
      if Sidekiq::Queue.new(:request).size > max_queue
        Lograge.job_logging('Tasks', 'info', 'Tasks::WorkersHandler', 'execute', {msg: 'Sidekiq::Queue Over Flow', queue_size: Sidekiq::Queue.new(:request).size})
        logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] OVER FLOW AND END"
        return :over_flow
      end

      # 完了処理
      if ( requests = Request.main.working + Request.main.all_working ).present?
        requests.each do |req|
          next unless req.reload.all_urls_finished?
          if req.corporate_list_site? && req.company_info_urls.size == 0
            req.update!(status: EasySettings.status[:arranging] )
            req.corporate_list_urls.update_all(arrange_status: RequestedUrl.arrange_statuses[:accepted])
            ResultArrangeWorker.perform_async(req.id)
          else
            req.complete
            ResultFile.create!(status: ResultFile.statuses[:accepted], request_id: req.id, final: true)
          end
        end
      end

      push_count = 0

      stop_queue.times do |i|
        break if push_count >= stop_queue

        break if Sidekiq::Queue.new(:request).size > max_queue

        # mainのnewとworkingを取得
        # Requestのstatusをworkingに変更
        requests = Request.catch_unfinished_requests(exe_request_num, user_ids)
        break if requests.size == 0

        requests.each do |request|
          break if push_count > stop_queue
          Lograge.job_logging('Tasks', 'info', 'Tasks::WorkersHandler', 'execute', {request: request.to_log})

          # working, waitingステータスは取り出さない。もし、エラーで強制終了させた際のworking, waitingステータスのものは手動で変更する必要がある。
          request.get_new_urls_and_update_status(search_url_num).each do |requested_url|
            break if Request.find(request.id).stop?
            RequestSearchWorker.perform_async(requested_url.id, requested_url.type, requested_url.url)
            push_count += 1
          end
        end

        exe_request_num = exe_request_num + 5 if push_count == 0
        break if push_count == 0 && i >= 5
      end

      logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] END"
    rescue => e
      Lograge.job_logging('Tasks', 'error', 'Tasks::WorkersHandler', 'execute', {error: e, err_msg: e.message, backtrace: e.backtrace})
      logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][#execute] Error #{e.message} #{e.backtrace}"
    end

    def logging(log, text)
      puts text
      log&.log(text)
    end

    def working_self_process?(self_action, test_log = nil)
      stdout, stderr, status = Open3.capture3("ps aux | grep WorkersHandler.#{self_action} -wc")
      unless status.success?
        logging test_log, "[#{Time.zone.now}][Tasks::WorkersHandler][##{self_action}] ERROR counting WorkersHandler.#{self_action} process. err: #{stderr}"
        raise 'ERROR counting self process'
      end

      # grepと自分自身も併せて4つ
      # admin    15932  0.0  0.0 119856  2848 ?        Ss   01:25   0:00 /bin/bash -l -c cd /opt/GETCD/releases/20220908162212 && bundle exec bin/rails runner -e production 'Tasks::WorkersHandler.execute' >> /opt/GETCD/shared/log/crontab.log 2>&1
      # admin    15995 80.4  5.1 563052 202852 ?       Sl   01:25   0:04 bin/rails runner -e production Tasks::WorkersHandler.execute
      # admin    16032  0.0  0.0 119856  2808 ?        S    01:25   0:00 sh -c ps aux | grep WorkersHandler.execute
      # admin    16034  0.0  0.0 119424   964 ?        S    01:25   0:00 grep WorkersHandler.execute
      return true if stdout.to_i > 4

      false
    end

    def count
      puts "[#{Time.zone.now}][Tasks::WorkersHandler][#count] WAIT: #{Sidekiq::Queue.new(:request).size}"
      puts "[#{Time.zone.now}][Tasks::WorkersHandler][#count] RETRY: #{Sidekiq::RetrySet.new.size}"
    end

    def clear_all
      puts "[#{Time.zone.now}][Tasks::WorkersHandler][#clear_all] START"
      Sidekiq::Queue.new(:request).clear
      Sidekiq::RetrySet.new.clear
      puts "[#{Time.zone.now}][Tasks::WorkersHandler][#clear_all] END"
    end

    private

    def mail_log_and_puts(log, msg)
      log << msg
      puts msg
    end

    def restart_lost_result_file_jobs(sidekiqer)
      candidate = []
      waiting_ids = sidekiqer.get_waiting_result_file_ids
      working_ids = sidekiqer.get_working_result_file_ids
      ResultFile.unfinished.each do |res_file|
        next if waiting_ids.include?(res_file.id)
        next if working_ids.include?(res_file.id)
        candidate << res_file
      end

      return if candidate.blank?

      sleep 2
      candidate2 = []
      waiting_ids = sidekiqer.get_waiting_result_file_ids
      working_ids = sidekiqer.get_working_result_file_ids
      candidate.each do |res_file|
        next if waiting_ids.include?(res_file.id)
        next if working_ids.include?(res_file.id)
        candidate2 << res_file
      end

      return if candidate2.blank?

      sleep 2
      waiting_ids = sidekiqer.get_waiting_result_file_ids
      working_ids = sidekiqer.get_working_result_file_ids
      candidate2.each do |res_file|
        next if waiting_ids.include?(res_file.id)
        next if working_ids.include?(res_file.id)
        res_file.update!(status: ResultFile.statuses[:waiting])
        ResultFileWorker.perform_async(res_file.id)
      end
    end

    def restart_lost_arrange_jobs(sidekiqer)
      candidate = []
      waiting_ids = sidekiqer.get_waiting_arrange_ids
      working_ids = sidekiqer.get_working_arrange_ids
      Request.arranging.each do |req|
        next if waiting_ids.include?(req.id)
        next if working_ids.include?(req.id)
        candidate << req
      end

      return if candidate.blank?

      sleep 2
      candidate2 = []
      waiting_ids = sidekiqer.get_waiting_arrange_ids
      working_ids = sidekiqer.get_working_arrange_ids
      candidate.each do |req|
        next if waiting_ids.include?(req.id)
        next if working_ids.include?(req.id)
        candidate2 << req
      end

      return if candidate2.blank?

      sleep 2
      waiting_ids = sidekiqer.get_waiting_arrange_ids
      working_ids = sidekiqer.get_working_arrange_ids
      candidate2.each do |req|
        next if waiting_ids.include?(req.id)
        next if working_ids.include?(req.id)
        ResultArrangeWorker.perform_async(req.id)
      end
    end

    def restart_lost_test_request_jobs(sidekiqer)
      limit = sidekiqer.get_test_working_job_limit
      return if limit == 0

      candidate = []
      waiting_ids = sidekiqer.get_waiting_test_request_ids
      working_ids = sidekiqer.get_working_test_request_ids
      Request.test_mode.unfinished.each do |req|
        next if waiting_ids.include?(req.id)
        next if working_ids.include?(req.id)
        candidate << req
      end

      return if working_ids.size >= limit
      return if candidate.blank?

      sleep 2
      candidate2 = []
      waiting_ids = sidekiqer.get_waiting_arrange_ids
      working_ids = sidekiqer.get_working_arrange_ids
      candidate.each do |req|
        next if waiting_ids.include?(req.id)
        next if working_ids.include?(req.id)
        candidate2 << req
      end

      return if working_ids.size >= limit
      return if candidate2.blank?

      sleep 2
      waiting_ids = sidekiqer.get_waiting_arrange_ids
      working_ids = sidekiqer.get_working_arrange_ids
      return if working_ids.size >= limit

      size = sidekiqer.get_working_analysis_step_request_size(limit)
      return if size >= limit

      perform_cnt = 0
      candidate2.each do |req|
        next if waiting_ids.include?(req.id)
        next if working_ids.include?(req.id)
        TestRequestSearchWorker.perform_async(req.id)
        perform_cnt += 1
        break if size + perform_cnt >= limit
      end
    end
  end
end
