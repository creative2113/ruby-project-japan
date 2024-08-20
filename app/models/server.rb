require "open3"

class Server

  class RebootError < StandardError; end

  attr_reader :log

  def initialize(log_tag = nil)
    @log_tag = log_tag
    @log = []
  end

  def reboot(log: nil)
    return nil if Rails.env.development? || Rails.env.test?

    # デプロイの停止ファイルチェック
    deploy_path = "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:deploying]}"
    if File.exist?(deploy_path)
      log_and_puts("[#{Time.zone.now}]#{@log_tag} デプロイ用のコントロールファイルが存在しています。 Cntl File Exsisted : #{deploy_path}", log: log)
      return :deploying
    end

    # サーバ再起動コントロールファイルを作成
    # [ルール1] コントロールファイルが存在しても、何度でも削除できる
    file_remove if rebooted?
    FileUtils.touch(reboot_path)

    NoticeMailer.deliver_now(NoticeMailer.notice_simple("再起動 サーバ\n\n#{Time.zone.now}", '再起動 サーバ', "【#{ENV['RAILS_ROLE'] }】バッチ"))

    # メールを送る時間を稼ぐ
    sleep 10

    if Rails.env.dev?
      CrawlTestWorker.set_server_reboot_key_for_crawl_test
      CrawlTestWorker.exit_execution
    end

    log_and_puts("[#{Time.zone.now}]#{@log_tag} サーバを再起動します。", log: log)
    stdout, stderr, status = Open3.capture3('sudo reboot')
    unless status.success?
      deliver(NoticeMailer.notice_simple("エラー発生\nコマンド [sudo reboot]\n\n" + stderr, 'Server reboot 再起動 サーバ', "【#{ENV['RAILS_ROLE'] }】バッチ"))
      raise RebootError, "ERROR server reboot: #{stderr}"
    end
  end

  def rebooted?
    File.exist?(reboot_path)
  end

  def remove_reboot_control_file(log: nil)
    return false unless rebooted?

    # [ルール2] 必ず、30分経過後に削除する
    # これをルールとし、これに基づいて、設計、実装を行う
    # コントロールファイルがある場合、ない場合を考慮してると大変なので、このルールは他のルールに依存せず、独立して存在する
    # ctimeは最終状態変更日時で作成日時ではないが、これを利用する
    return false unless File::Stat.new(reboot_path).ctime < Time.zone.now - 30.minutes

    file_remove
    log_and_puts("[#{Time.zone.now}]#{@log_tag} Remove Server Reboot Cntl File : #{reboot_path}", log: log)
    NoticeMailer.deliver_later(NoticeMailer.notice_simple("Server Rebootedファイル 削除", 'Server remove_reboot_control_file', "【#{ENV['RAILS_ROLE'] }】バッチ"))

    true
  end

  private

  def file_remove
    FileUtils.rm_f(reboot_path)
  end

  def reboot_path
    "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:server_reboot]}"
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
