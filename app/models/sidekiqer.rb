require "open3"

class Sidekiqer

  class ReloadError < StandardError; end

  class StopError < StandardError; end

  class StartError < StandardError; end

  attr_reader :log, :error

  def initialize(log_tag = nil)
    @log_tag = log_tag
    @log = []
    @error = nil
  end

  def get_concurrencies
    map = {}
    Sidekiq::ProcessSet.new.each do |process|
      map[process['queues']] = process['concurrency']
    end
    map
  end

  def active_process?(queues)
    Sidekiq::ProcessSet.new.each do |process|
      return true if queues.select { |q| !process['queues'].include?(q) }.blank?
    end
    false
  end

  def get_test_working_job_limit
    con = get_concurrencies.select { |queues| queues.include?('request') }.values[0].to_i
    return 0 if con == 0
    limit = ( con / 3 ).to_i
    limit = 1 if limit <= 0
    limit
  end

  def get_timeout_jobs(timeout_company_info_min = 15, timeout_corp_list_min = 30)
    multi_ci_jobs       = []
    single_search_jobs  = []
    corp_list_jobs      = []
    test_corp_list_jobs = []

    Sidekiq::Workers.new.each do |process_id, thread_id, work|
      next unless ['request', 'search', 'test_request'].include?(work['queue'])
      data = info(work)
      id = data[:id]

      if data[:queue] == 'request' && data[:class] == 'RequestSearchWorker' && data[:args][1] == 'SearchRequest::CompanyInfo'

        multi_ci_jobs << id if Time.zone.at(data[:run_at]) < Time.zone.now - timeout_company_info_min.minutes

      elsif data[:queue] == 'search' && data[:class] == 'SearchWorker'

        single_search_jobs << id if Time.zone.at(data[:run_at]) < Time.zone.now - timeout_company_info_min.minutes

      elsif data[:queue] == 'request' && data[:class] == 'RequestSearchWorker'

        corp_list_jobs << id if Time.zone.at(data[:run_at]) < Time.zone.now - timeout_corp_list_min.minutes

      elsif data[:queue] == 'test_request' && data[:class] == 'TestRequestSearchWorker'

        test_corp_list_jobs << id if Time.zone.at(data[:run_at]) < Time.zone.now - timeout_corp_list_min.minutes

      end
    end

    { company_info: multi_ci_jobs, search_request: single_search_jobs, corp_list: corp_list_jobs,  test_corp_list: test_corp_list_jobs }
  end

  def get_waiting_test_request_ids
    Sidekiq::Queue.new(:test_request).map { |d| d.item['args'][0] }
  end

  def get_working_test_request_ids
    ids = []
    Sidekiq::Workers.new.map do |process_id, thread_id, work|
      next if ['mailers', 'default'].include?(work['queue'])
      data = info(work)

      ids << data[:id].to_i if data[:queue] == 'test_request'
    end
    ids
  end

  def get_working_analysis_step_request_size(limit = nil, self_req_id = nil)
    res = get_working_request_ids

    res[:test_request].delete_if { |id| id.to_i == self_req_id }
    test_size = res[:test_request].size

    return test_size if limit.present? && test_size >= limit

    analysis_step_size = 0
    res[:requested_urls].each do |req_url_id|
      req = RequestedUrl.find(req_url_id)&.request
      next if req.id == self_req_id
      analysis_step_size += 1 if req.type == 'corporate_list_site' && req.list_site_analysis_result.blank?
    end

    test_size + analysis_step_size
  end

  def over_limit_working_analysis_step_requests?(self_req_id = nil)
    limit = get_test_working_job_limit
    get_working_analysis_step_request_size(limit, self_req_id) >= limit ? true : false
  end

  def get_waiting_result_file_ids
    Sidekiq::Queue.new(:make_result).map { |d| d.item['args'][0] }
  end

  def get_working_result_file_ids
    ids = []
    Sidekiq::Workers.new.map do |process_id, thread_id, work|
      next if ['mailers', 'default'].include?(work['queue'])
      data = info(work)

      ids << data[:id].to_i if data[:queue] == 'make_result'
    end
    ids
  end

  def get_waiting_arrange_ids
    Sidekiq::Queue.new(:arrange).map { |d| d.item['args'][0] }
  end

  def get_working_arrange_ids
    ids = []
    Sidekiq::Workers.new.map do |process_id, thread_id, work|
      next if ['mailers', 'default'].include?(work['queue'])
      data = info(work)
      ids << data[:id].to_i if data[:queue] == 'arrange'
    end
    ids
  end

  def get_retry_request_ids
    Sidekiq::RetrySet.new.map do |retry_set|
      next unless retry_set.item['queue'] == 'request'
      retry_set.item['args'][0].to_i
    end
  end

  def get_waiting_request_ids
    Sidekiq::Queue.new(:request).map { |d| d.item['args'][0] }
  end

  def get_working_request_ids
    req_url_ids    = []
    search_req_ids = []
    test_req_ids   = []

    Sidekiq::Workers.new.each do |process_id, thread_id, work|
      next if ['mailers', 'default'].include?(work['queue'])
      data = info(work)

      id = data[:id].to_i
      req_url_ids    << id if data[:queue] == 'request'
      search_req_ids << id if data[:queue] == 'search'
      test_req_ids   << id if data[:queue] == 'test_request'
    end
    { requested_urls: req_url_ids, search_requests: search_req_ids, test_request: test_req_ids }
  end

  def get_working_company_info_url_ids
    Sidekiq::Workers.new.map do |process_id, thread_id, work|
      next if ['mailers', 'default'].include?(work['queue'])
      data = info(work)

      next unless ( data[:queue] == 'request' && data[:class] == 'RequestSearchWorker' )
      next unless data[:args][1] == 'SearchRequest::CompanyInfo'
      data[:args][0].to_i
    end.compact
  end

  def waiting_ids
    Sidekiq::Queue.new(:request).map { |queue| queue['args'][0] }
  end

  def include_waiting(ids)
    waiting = waiting_ids

    ids.select { |id| waiting.include?(id) }
  end

  def alive_process?(job_name)
    Sidekiq::ProcessSet.new.each do |sq|
      next if sq['quiet'] == 'true'
      next unless sq['queues'].include?(job_name)
      return true
    end
    false
  end

  def get_quiet_process
    quiet_processes = []
    Sidekiq::ProcessSet.new.each do |sq|
      quiet_processes << sq['queues'].join('_') if sq['quiet'] == 'true'
    end
    quiet_processes
  end

  # 基本使わないこと
  # 使用用途 => デプロイのsafe stop
  def all_quiet!(log = nil)
    # sidekiq:quiet
    # 新しいジョブを実行しなくなる。キューに貯まる

    Sidekiq::ProcessSet.new.each(&:quiet!)
    log_and_puts("[#{Time.zone.now}]#{@log_tag} quiet sidekiq all process", log: log)

    # quietのタイムラグが最大5秒のため、10秒待つ。
    sleep 10
  end

  def quiet_request_process!(log = nil)
    # sidekiq:quiet
    # 新しいジョブを実行しなくなる。キューに貯まる

    Sidekiq::ProcessSet.new.each do |process|
      process.quiet! if process['queues'].include?('request')
    end
    log_and_puts("[#{Time.zone.now}]#{@log_tag} quiet sidekiq request worker", log: log)

    # quietのタイムラグが最大5秒のため、10秒待つ。
    sleep 10
  end

  # sidekiqを止める
  # 自動再開しない
  def stop_sidekiq!(name, log = nil)
    return unless ( Rails.env.dev? || Rails.env.production? )

    # sidekiq:stop
    # quiet!にしてから、終了する。終了するまで時間がかかる。終了しなかったJOBは待機中に戻す
    # 待機中は残り続ける
    stdout, stderr, status = Open3.capture3("sudo systemctl stop #{name}")
    unless status.success?
      log_and_puts("[#{Time.zone.now}]#{@log_tag} ERROR Stop Sidekiq #{name}. Err: #{stderr}", log: log)
      raise StopError, "ERROR stop sidekiq: #{stderr}"
    end
    log_and_puts("[#{Time.zone.now}]#{@log_tag} Stopped Sidekiq", log: log)
  end

  def start!(name, log = nil)
    return unless ( Rails.env.dev? || Rails.env.production? )

    # sidekiq:start
    stdout, stderr, status = Open3.capture3("sudo systemctl start #{name}")
    unless status.success?
      log_and_puts("[#{Time.zone.now}]#{@log_tag} ERROR start sidekiq #{name}. Err: #{stderr}", log: log)
      raise StartError, "ERROR start sidekiq: #{stderr}"
    end
    log_and_puts("[#{Time.zone.now}]#{@log_tag} Started Sidekiq", log: log)

    sleep 2
  end

  def recovery_memory(log: nil)
    NoticeMailer.deliver_later(NoticeMailer.notice_simple("リカバリ メモリー 開始\nメモリ #{Memory.current} M", 'リカバリ メモリ バッチ recovery_memory 開始', 'バッチ'))
    log_and_puts("[#{Time.zone.now}][Sidekiqer][#recovery_memory] START")

    @log_tag = '[RECOVERY MEMORY]'
    reboot_request_sidekiq(log: log, reason: 'リカバリ メモリー')

    NoticeMailer.deliver_later(NoticeMailer.notice_simple("正常終了\n" + @log.join("\n"), 'リカバリ メモリー バッチ recovery_memory 正常終了', 'バッチ'))
    true
  rescue => e
    logging('error', 'recovery_memory', { issue: "Error.", error: e, err_msg: e.message, backtrace: e.backtrace})
    false
  end

  def timeout_job_stop!(timeout_min:, log: nil)
    stop_ids = get_timeout_jobs(timeout_min)
    if stop_ids.values.all?(&:blank?)
      return false
    end

    reboot_request_sidekiq(timeout_min: timeout_min, log: log, reason: 'タイムアウトジョブ')

  rescue => e
    logging('fatal', 'timeout_job_stop!', { issue: "ジョブストップ Error.", log: @log.join("\n"), error: e, err_msg: e.message, backtrace: e.backtrace})
    true
  end

  def rebooting_now?
    File.exist?(cntl_path)
  end

  def deploying_now?
    File.exist?(deploy_path)
  end

  # 時間がかかっているものを止めること
  # Chromeをキルして、メモリー確保
  # 定期的な再起動

  # リカバリーメモリー => ヘルスチェック、     Requestのみストップ、すぐ開始
  # 15分タイムストップ => ワーカーズハンドラー、Requestのみストップ、すぐ開始
  # EXCEL作成ストップ => ResultFileワーカー、Requestのみストップ、ジョブ完了後
  # 3時間ごとの再起動 => ワーカーズハンドラー、Requestのみストップ、すぐ開始
  # デプロイストップ   => 手動、             全体ストップ、　　　　デプロイ後
  def reboot_request_sidekiq(timeout_min: 15, log: nil, reason: nil)

    res = stop_request_sidekiq_in_reboot(timeout_min: timeout_min, log: log, reason: reason)

    if [:rebooting, :deploying, :error].include?(res)
      return res
    end

    # メモリーが復活しているかチェック
    # 復活しなければ、サーバから再起動
    check_memory_and_reboot_server(log: log)

    start_request_sidekiq_in_reboot(res, log: log)

  rescue => e
    if res.present? && res.class == Hash
      msg = "終了しなかったリクエストURL ID: #{res[:req_ids]}\nタイムアウトしたリクエストURL ID: #{res[:stop_ids]}\n終了しなかったジョブ: #{res[:unfinished_jobs]}"
    end
    logging('fatal', 'reboot_sidekiq', { issue: "Sidekiq再起動 Error\n#{msg}", log: @log.join("\n"), error: e, err_msg: e.message, backtrace: e.backtrace})
  end

  def check_memory_and_reboot_server(log: nil)
    sleep 10
    if ( mem = Memory.average(count: 5, interval: 3) ) < 1_400
      NoticeMailer.deliver_now(NoticeMailer.notice_simple("再起動 サーバ\n\nメモリー 平均: #{mem}M", '再起動 サーバ', 'バッチ'))

      Server.new(@log_tag).reboot(log: log)
    end
  end

  def stop_request_sidekiq_in_reboot(timeout_min: 15, log: nil, reason: nil)

    req_ids         = { requested_urls: [], search_requests: [] }
    stop_ids        = { company_info: [], search_request: [] }
    unfinished_jobs = []

    # デプロイの停止ファイルチェック
    deploy_path = "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:deploying]}"
    if File.exist?(deploy_path)
      log_and_puts("[#{Time.zone.now}]#{@log_tag} デプロイ用のコントロールファイルが存在しています。 Cntl File Exsisted : #{deploy_path}", log: log)
      return :deploying
    end


    # コントロールファイルチェック
    if File.exist?(cntl_path)
      log_and_puts("[#{Time.zone.now}]#{@log_tag} Reboot Cntl File Exsisted : #{cntl_path}", log: log)
      return :rebooting
    end


    log_and_puts("[#{Time.zone.now}]#{@log_tag} START Sidekiq Reboot", log: log)
    NoticeMailer.deliver_later(NoticeMailer.notice_simple("再起動 Sidekiq 開始 #{reason}", "再起動 Sidekiq 開始 #{reason}", 'バッチ'))


    # コントロールファイル作成。これで、Tasks::WorkersHandler.executeは止まる。
    # RequestSearchWorkerのジョブも途中で止まる。
    FileUtils.touch(cntl_path) unless File.exist?(cntl_path)
    log_and_puts("[#{Time.zone.now}]#{@log_tag} Made Reboot Cntl File : #{cntl_path}", log: log)


    quiet_request_process!(log)

    # 15分以上経っているものは削除する
    # 終了できるものは終了させる
    # メモリーが不足している可能性も考慮し、終わらせるものは終わらせる

    if Memory.current < 400 && ( mem = Memory.average(count: 5, interval: 3) ) < 500
      # メモリが枯渇している場合はまたない
      log_and_puts("[#{Time.zone.now}]#{@log_tag} Too Memory Shortage 平均: #{mem} M", log: log)
    else
      100.times do |i| # 5分ほど待つ
        continue = false
        exec_ids = get_working_request_ids
        log_and_puts("[#{Time.zone.now}]#{@log_tag} Waiting Finish Job. Exec Job IDs : #{exec_ids}", log: log) if i%10 == 0

        Sidekiq::Workers.new.each do |process_id, thread_id, work|
          data = info(work)
          next unless ['search', 'test_request', 'request'].include?(data[:queue])
          next if Time.zone.now - timeout_min.minutes > Time.zone.at(data[:run_at]) # 15分経過しているものは無視
          continue = true
        end
        break unless continue
        sleep 3
      end
    end

    unfinished_jobs = Sidekiq::Workers.new.map { |process_id, thread_id, work| work['payload'] }

    if unfinished_jobs.present?
      req_ids  = get_working_request_ids
      stop_ids = get_timeout_jobs(timeout_min)
    else
      log_and_puts("[#{Time.zone.now}]#{@log_tag} All Finished Job", log: log)
    end


    # まずは止める！！
    # 自動再開しない
    stop_sidekiq!('sidekiq', log)

    log_and_puts("[#{Time.zone.now}]#{@log_tag} Before Memory => #{Memory.free_and_available}", log: log)

    killer = ChromeKiller.new(@log_tag)
    killer.execute(log)
    @log.concat(killer.log)

    GC.start # ガーベジコレクション

    log_and_puts("[#{Time.zone.now}]#{@log_tag} After Memory 1 => #{Memory.free_and_available}", log: log)

    sleep 1

    log_and_puts("[#{Time.zone.now}]#{@log_tag} After Memory 2 => #{Memory.free_and_available}", log: log)


    # 企業一覧クロール
    # 大事なポイントのURLでないかのチェック
    req_urls = RequestedUrl.eager_load(:request).where(id: req_ids[:requested_urls])
    req_urls.each do |req_url|
      if ( marker = Redis.new.get(marker_key(req_url.id)) ).present?
        NoticeMailer.deliver_later(NoticeMailer.notice_simple("クロール重要マーカーあり\nリクエストID: #{req_url.request.id} リクエストURL ID: #{req_url.id}\nマーカー #{marker}", '重要マーカー reboot_sidekiq', 'バッチ'))
      end

      req_url.complete(EasySettings.finish_status.timeout) if stop_ids[:company_info].include?(req_url.id)
      req_url.complete(EasySettings.finish_status.timeout) if stop_ids[:corp_list].include?(req_url.id)
    end

    # テスト
    req_urls = RequestedUrl.eager_load(:request).where(id: req_ids[:test_request])
    req_urls.each do |req_url|
      if stop_ids[:test_corp_list].include?(req_url.id)
        req_url.complete(EasySettings.finish_status.timeout)
      else
        req_url.update!(status: EasySettings.status[:waiting], finish_status: EasySettings.finish_status.new)
      end
    end

    reqs = SearchRequest.where(id: req_ids[:search_requests])
    reqs.each do |search_req|
      search_req.complete(EasySettings.finish_status.timeout) if stop_ids[:search_request].include?(search_req.id)
    end

    GC.start # ガーベジコレクション

    {req_ids: req_ids, stop_ids: stop_ids, unfinished_jobs: unfinished_jobs}

  rescue => e
    log_and_puts("[#{Time.zone.now}]#{@log_tag} Error発生 : #{e.class} #{e.message}", log: log)
    logging('fatal', 'stop_request_sidekiq', { issue: "Sidekiq再起動中の停止フェーズ Error\n終了しなかったリクエストURL ID: #{req_ids}\nタイムアウトしたリクエストURL ID: #{stop_ids}\n終了しなかったジョブ: #{unfinished_jobs}", log: @log.join("\n"), error: e, err_msg: e.message, backtrace: e.backtrace})
    FileUtils.rm_f(cntl_path)
    log_and_puts("[#{Time.zone.now}]#{@log_tag} Remove Stop Cntl File : #{cntl_path}", log: log)
    :error
  end

  # stop_request_sidekiq の後に実行すること
  def start_request_sidekiq_in_reboot(res_stop, log: nil)
    # コントロールファイルチェック
    return :unrebooting unless remove_reboot_control_file(log: log)

    # sidekiq:start
    start!('sidekiq', log)
    sleep 2

    log_and_puts("[#{Time.zone.now}]#{@log_tag} END Sidekiq Reboot", log: log)

    NoticeMailer.deliver_later(NoticeMailer.notice_simple("再起動 Sidekiq 終了\n終了しなかったリクエストURL ID: #{res_stop[:req_ids]}\nタイムアウトしたリクエストURL ID: #{res_stop[:stop_ids]}\n終了しなかったジョブ: #{res_stop[:unfinished_jobs]}\nログ:\n#{@log.join("\n")}", '再起動 Sidekiq 終了', 'バッチ'))
  end

  def remove_reboot_control_file(log: nil)
    unless File.exist?(cntl_path)
      log_and_puts("[#{Time.zone.now}]#{@log_tag} Run stop_request_sidekiq at first! Control file is not existed!! : #{cntl_path}", log: log)
      return false
    end

    FileUtils.rm_f(cntl_path)
    log_and_puts("[#{Time.zone.now}]#{@log_tag} Remove Stop Cntl File : #{cntl_path}", log: log)
    true
  end

  def wait_current_exec_jobs(until_cmplete_queue: false)
    start = Time.now
    # 実行中のjobが終わるまで待つ
    500.times do |i|
      # すぐには反映されない
      if exist_working_job?(until_cmplete_queue)
        sleep 10
        if exist_working_job?(until_cmplete_queue)
          sleep 10
          if exist_working_job?(until_cmplete_queue)
            sleep 10
            break if exist_working_job?(until_cmplete_queue)
          end
        end
      end

      sleep 3

      if Time.now - start > 900 # 15分を超えたらアラート
        return false
      end
    end

    return true
  end

  private

  def exist_working_job?(until_cmplete_queue)
    ( !until_cmplete_queue && Sidekiq::Workers.new.size == 0 ) ||
    ( until_cmplete_queue && Sidekiq::Workers.new.size == 0 && Sidekiq::Queue.new(:mailer).count == 0 )
  end

  def cntl_path
    "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:sidekiq_reboot]}"
  end

  def deploy_path
    "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:deploying]}"
  end

  def info(work)
    payload = Json2.parse(work['payload'])

    if work['run_at'].blank? || payload[:queue].blank? || payload[:class].blank? || payload[:args].blank?
      NoticeMailer.deliver_later(NoticeMailer.notice_simple("Sidekiqer 解析 失敗!!\n引数work = \n#{work}", 'Sidekiqer 解析異常', 'Sidekiqer異常'))
    end

    { run_at: work['run_at'], queue: payload[:queue], class: payload[:class],  id: payload[:args][0], args: payload[:args] }
  end

  def marker_key(id)
    "crawl_point_marker #{id}"
  end

  def logging(level = 'info', method = '', contents = {})
    Lograge.job_logging('WOKER', level, 'Sidekiqer', method, contents)
  end

  def log_and_puts(msg, allow_puts: true, log: nil)
    @log << msg
    if log.present? && log.class == MyLog
      log.log(msg)
    elsif log.class == Array
      log << msg
    end
    puts msg if allow_puts
  end
end
