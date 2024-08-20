require "open3"

class ResultFileWorker
  include Sidekiq::Worker
  sidekiq_options queue: :make_result, retry: false, backtrace: 20
  sidekiq_options tags: ['result']

  # 考慮するポイント
  #    ずっとaccepted, waiting, makingで終わらない => ワーカーハンドラーで発見し、再実行
  #    リクエストワーカが終わらない => 15分強制終了が働くまで、ループで待ち続ける
  #    エラーが出た場合
  #       実行中のものは => エラーで知らせる。続きから再開できる。各フェーズで冪等になっているので。
  #       停止したリクエストワーカは？ 正常も終了も再開させる。
  #    途中で終了した => 続きから再開できる。各フェーズで冪等になっているので。
  #    メモリ不足 => 監視 & サイドキック再起動はしないようにする

  #    デプロイとの競合 => キューに入ってれば、削除しても、後から実行されるので削除！途中のものはやり切る
  #    sidekiq再起動との競合 => 一旦、returnして、再度実行させる

  def perform(result_file_id)

    step = 1
    GC.start

    result_file = ResultFile.find_by(id: result_file_id)
    request     = result_file&.request
    ActiveRecord::Base.connection.close

    return if result_file.blank? || request.blank?
    return if result_file.finished?

    # アレンジング中は実行させない
    return if request.status == EasySettings.status.arranging

    step = 2

    my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] START"
    Lograge.job_logging('WOKER', 'info', 'ResultFileWorker', 'perform', {message: 'Start', result_file: result_file.id, request: request.to_log})


    start_time = Time.zone.now

    result_file.reload.update!(status: ResultFile.statuses[:making], started_at: Time.zone.now)

    while result_file.making? do
      ActiveRecord::Base.connection.close

      if result_file.reload.parameters.present? && result_file.parse_params[:stop_sidekiq] && step != 3
        reboot_res = Sidekiqer.new('[ResultFileWorker][#execute]').stop_request_sidekiq_in_reboot(timeout_min: 15, log: my_log, reason: 'ResultFileWorker.perform')
        if [:rebooting, :deploying].include?(reboot_res)
          my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] Sidekiq Rbbooting 実行中 : #{reboot_res}"
          my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] END"
          result_file.reload.update!(status: ResultFile.statuses[:waiting])
          return
        elsif reboot_res == :error
          my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] Sidekiq Rbbooting エラー : #{reboot_res}"
          my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] END"
          result_file.reload.update!(status: ResultFile.statuses[:waiting])
          return
        end

        step = 3
      end

      cmd_execute(result_file)
      # result_file.make_file # <- デバッグしたい時

      result_file.reload
    end

    deliver_mail_for_final(request) if result_file.final?

    # 再開させる
    if step == 3
      Sidekiqer.new('[ResultFileWorker][#execute]').start_request_sidekiq_in_reboot(reboot_res, log: my_log)
    end

    Lograge.job_logging('WOKER', 'info', 'ResultFileWorker', 'execute', { issue: "Normal Finish", process_time: Time.zone.now - start_time, result_file: result_file.id, request: request.to_log})

    my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] END"

  rescue => e
    MyLog.new('my_crontab').log "#{e.class} #{e.message} #{e.backtrace[0..5]}"
    Lograge.job_logging('WOKER', 'error', 'ResultFileWorker', 'perform', { issue: 'Result File Make Error', err_msg: e.message, backtrace: e.backtrace})

    NoticeMailer.deliver_later(NoticeMailer.notice_simple("エクセル作成バッチ\n ResultFile ID: #{result_file.id} Phase: #{result_file.phase}\n#{e.class}\n#{e.message}\n#{e.backtrace}", 'エクセル作成でエラー発生', 'エクセルバッチ')) if step >= 2

    result_file.update!(status: ResultFile.statuses[:error]) if step >= 2
    Sidekiqer.new('[ResultFileWorker][#execute]').start_request_sidekiq_in_reboot(reboot_res, log: my_log) if step == 3
  end

  class << self
    def make(id = nil)
      result_file = ResultFile.find_by(id: id)
      MyLog.new('my_crontab').log "[#{Time.zone.now}][ResultFileWorker][#make] START #{result_file.to_log}  #{Memory.free_and_available}"

      result_file.make_file

      MyLog.new('my_crontab').log "[#{Time.zone.now}][ResultFileWorker][#make] END   #{result_file.reload.to_log}  #{Memory.free_and_available}"
    end
  end

  private

  def cmd_execute(result_file)
    cmd = if Rails.env.production? || Rails.env.dev?
      "/bin/bash -l -c 'cd /home/admin/current && bundle exec bin/rails runner -e #{Rails.env} \"ResultFileWorker.make(#{result_file.id})\"'"
    else
      "cd /Users/isotoshihiro/iso-app/GETCD && bundle exec bin/rails runner -e #{Rails.env} \"ResultFileWorker.make(#{result_file.id})\""
    end
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.success?
      my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] ERROR make action. err: #{stderr}"
      return
    end
    my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] STDOUT #{stdout}" if stdout.present?
    my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] STDERR #{stderr}" if stderr.present?
    my_log.log "[#{Time.zone.now}][ResultFileWorker][#execute] STATUS #{status}"
  end

  def my_log
    MyLog.new('my_crontab')
  end

  def deliver_mail_for_final(request)
    if request.registered_user?
      NoticeMailer.deliver_later(NoticeMailer.request_complete_mail_for_user(request))
    else
      NoticeMailer.deliver_later(NoticeMailer.request_complete_mail(request)) if request.mail_address.present?
    end
  rescue => e
    Lograge.job_logging('WOKER', 'error', 'ResultFileWorker', 'perform', { issue: 'Mail delivery Error', err_msg: e.message, backtrace: e.backtrace})
  end
end
