require "open3"

class ChromeKiller

  attr_reader :log, :error

  def initialize(log_tag = nil)
    @log_tag = log_tag
    @log = []
    @error = nil
  end

  def find_jobs(log = nil)
    stdout, stderr, status = Open3.capture3("ps aux | grep chrome")
    unless status.success?
      @error = stderr
      log_and_puts("[#{Time.zone.now}]#{@log_tag} ERROR ps grep chrome. Err: #{stderr}", log: log)
      return false
    end
    stdout.split("\n")
  end

  def kill(jobs, log = nil)
    if jobs.size <= 1
      log_and_puts("[#{Time.zone.now}]#{@log_tag} Nothing Chrome To Kill.", log: log)
      return true
    end

    pids = jobs.map do |str|
      log_and_puts("[#{Time.zone.now}]#{@log_tag} Current Chrome: #{str}", log: log)
      str.split(' ')[1]
    end

    count = pids.size
    log_and_puts("[#{Time.zone.now}]#{@log_tag} Current Chrome. Count: #{pids.size} PID: #{pids}", log: log)

    cmd = %w(sudo kill -kill)
    pids.each { |id| cmd << id.shellescape }

    stdout, stderr, status = Open3.capture3(*cmd)

    unless status.success?
      log_and_puts("[#{Time.zone.now}]#{@log_tag} ERROR Kill Chrome. Err: #{stderr}", log: log)

      flg = false
      stderr.split("\n").each { |err| (flg = true; break) unless err.include?('No such process') }
      if flg
        @error = stderr
        return false
      end
    end

    log_and_puts("[#{Time.zone.now}]#{@log_tag} Kill Chrome. Count: #{pids.size}", log: log)
    true
  end

  def execute(log = nil)
    jobs = find_jobs(log)
    unless jobs
      NoticeMailer.deliver_later(NoticeMailer.notice_simple("エラー発生\n" + @log.join("\n"), 'エラー。Chrome Kill Find Job', 'バッチ'))
    end

    unless kill(jobs, log)
      NoticeMailer.deliver_later(NoticeMailer.notice_simple("エラー発生\n" + @log.join("\n"), 'エラー。Chrome Kill Kill Job', 'バッチ'))
    end
  end

  private

  def log_and_puts(msg, log: nil)
    @log << msg
    if log.present? && log.class == MyLog
      log.log(msg)
    elsif log.class == Array
      log << msg
    end
    puts msg
  end
end
