require 'yaml'

class CrawlTestWorker

  class << self

    def execute
      return if Rails.env.production?
      GC.start

      ct_normal = nil
      ct_xpath = nil

      return if Sidekiqer.new.deploying_now? || Sidekiqer.new.rebooting_now?
      return unless exist_file?

      log = MyLog.new('crawl_test')
      log.log('start')
      result_log = MyLog.new('crawl_test_result', dir_path: '/home/admin', rotate: false)


      # redisで排他制御する
      unless can_start?
        log.log('can not start')
        return
      end

      unless exist_file?
        log.log('unexist file so stop')
        return exit_execution
      end

      path = '/home/admin/crawl_test_continue'
      FileUtils.touch(path)

      order = get_order
      mode = order['mode'] ? :queue : :normal

      if ['all', 'normal'].include?(order['pattern'])
        ct_normal = CrawlerTest::Execution.new(mode: mode, stop: false, host: '', finish_file: path, log: log, result_log: result_log)
        set_range(ct_normal, order['range_nums'])
        ct_normal.exec
      end


      if ['all', 'xpath'].include?(order['pattern'])
        CrawlTestWorker.make_order_file(mode: order['mode'], pattern: 'xpath')
        ct_xpath = CrawlerTest::XpathExecution.new(mode: mode, stop: false, host: '', finish_file: path, log: log, result_log: result_log)
        ct_xpath.exec
      end

      NoticeMailer.deliver_later(NoticeMailer.notice_simple("結果\n#{result_log&.read}", 'クロールテスト終了'))

      delete_order_file
      exit_execution
    rescue ActiveRecord::RecordNotFound => e
      log.log("#{e.class}  #{e.message}")
      Lograge.job_logging('Workers', 'error', 'CrawlTestWorker', 'execute', { issue: 'CrawlTest Execute Error', err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
    rescue RedisClient::CannotConnectError => e
      log.log("#{e.class}  #{e.message}")
      Lograge.job_logging('Workers', 'error', 'CrawlTestWorker', 'execute', { issue: 'CrawlTest Execute Error', err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      NoticeMailer.deliver_later(NoticeMailer.notice_simple("#{e.class}  #{e.message}", 'クロールテスト エラー終了'))
      exit_execution
    rescue => e
      log.log("#{e.class}  #{e.message}")
      Lograge.job_logging('Workers', 'error', 'CrawlTestWorker', 'execute', { issue: 'CrawlTest Execute Error', err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      NoticeMailer.deliver_later(NoticeMailer.notice_simple("結果\n#{result_log&.read}", 'クロールテスト エラー終了'))

      delete_order_file
      exit_execution
    end

    def set_range(crawl_test, range_nums)
      return if range_nums.blank?

      nums = range_nums.split(' ')
      if nums.size == 1 && nums[0].split('..').size == 2
        crawl_test.start = nums[0].split('..')[0]
        crawl_test.end   = nums[0].split('..')[1]
      else
        crawl_test.assign = nums
      end
    end

    def get_order
      return nil unless exist_file?
      open(test_order_file, 'r') { |f| YAML.load(f) }
    end

    # pattern = ['all', 'normal', 'xpath']
    def make_order_file(mode: true, pattern: 'all', range_nums: '')
      data = { 'mode' => mode,
               'pattern' => pattern,
               'range_nums' => range_nums }
      yaml_data = YAML.dump(data)
      File.open(test_order_file, 'w') {|f| f.write(yaml_data)}
    end

    def start_ctl_key
      'crawl_test_start_key'
    end

    def can_start?
      redis = Redis.new
      return false if redis.get(server_reboot_key_for_crawl_test).present?
      redis.set(start_ctl_key, 'true', nx: true, ex: 4*60*60)
    end

    def exit_execution
      redis = Redis.new
      redis.del(start_ctl_key)
    end

    def server_reboot_key_for_crawl_test
      'server_reboot_key_for_crawl_test'
    end

    def set_server_reboot_key_for_crawl_test
      redis = Redis.new
      redis.multi do |pipeline|
        pipeline.set(server_reboot_key_for_crawl_test, '1')
        pipeline.expire(server_reboot_key_for_crawl_test, 2*60)
      end
    end

    def exist_file?
      File.exist?(test_order_file)
    end

    def make_start_file
      FileUtils.touch(test_order_file) unless start?
    end

    def delete_order_file
      FileUtils.rm_f(test_order_file)
    end

    def test_order_file
      "#{Rails.application.credentials.control_directory[:path]}/crawl_test_order.yml"
    end

    def delete_result_file
      FileUtils.rm_f('/home/admin/crawl_test_result.log')
    end
  end
end
