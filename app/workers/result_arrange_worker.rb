require "open3"

class ResultArrangeWorker
  include Sidekiq::Worker
  sidekiq_options queue: :arrange, retry: false, backtrace: 20
  sidekiq_options tags: ['arrange']

  class ErrorStatusStop < StandardError; end

  # 考慮するポイント
  #    エラー => DBを修正して、再度、実行。冪等になっているので、大丈夫。

  def perform(request_id)

    GC.start

    ids = Sidekiqer.new.get_working_arrange_ids
    return if ids.include?(request_id)

    @request = Request.find_by(id: request_id)
    ActiveRecord::Base.connection.close

    return if @request.blank?
    if @request.test? || @request.status != EasySettings.status[:arranging] || @request.corporate_list_urls.main&.size&.zero?
      @request.update!(status: EasySettings.status[:completed])
      ActiveRecord::Base.connection.close
      return
    end

    test_option

    my_log.log "[#{Time.zone.now}][ResultArrangeWorker][#perform] START ID:#{@request.id}"
    Lograge.job_logging('WOKER', 'info', 'ResultArrangeWorker', 'perform', {message: 'Start',  request: @request.to_log})


    start_time = Time.zone.now

    @url_count = 0
    @limit_count = EasySettings.excel_row_limit[@request.plan_name]

    arrange_all_corporate_lists if @request.list_site_result_headers.blank?

    unless @test_mode
      # 全て削除
      @request.corporate_single_urls.main.destroy_all
      @request.corporate_list_urls.main.destroy_all
    end


    @request.set_working
    ActiveRecord::Base.connection.close

    crawl_test_save_new_urls

    Lograge.job_logging('WOKER', 'info', 'ResultArrangeWorker', 'perform', { issue: "Normal Finish", process_time: Time.zone.now - start_time, request: @request.to_log})

    cnt = @request.company_info_urls.size

    my_log.log "[#{Time.zone.now}][ResultArrangeWorker][#perform] END ID:#{@request.id} COUNT:#{cnt}  URL_COUNT:#{@url_count} Duration: #{Time.zone.now - start_time}"

  rescue => e
    my_log.log "[#{Time.zone.now}][ResultArrangeWorker][#perform] Error #{@corp_list_url.id} #{e.class} #{e.message} #{e.backtrace[0..5]}"
    Lograge.job_logging('WOKER', 'error', 'ResultArrangeWorker', 'perform', { issue: 'Result Arrange Error', err_class: e.class, err_msg: e.message, backtrace: e.backtrace})

    NoticeMailer.deliver_later(NoticeMailer.notice_simple("アレンジバッチ エラー\n Request ID: #{@request.id} REQ_URL:#{@corp_list_url.id}\n#{e.class}\n#{e.message}\n#{e.backtrace}", 'アレンジでエラー発生', 'Confirm アレンジバッチ'))
  end

  private

  def arrange_all_corporate_lists
    @data_combiner = DataCombiner.new(request: @request)

    @request.corporate_list_urls.each_with_index do |corp_list_url, i|
      if corp_list_url.test?
        corp_list_url.update!(arrange_status: RequestedUrl.arrange_statuses[:completed])
        next
      end

      @corp_list_url = corp_list_url
      GC.start

      my_log.log "[#{Time.zone.now}][ResultArrangeWorker][#perform] #{i} START  #{@url_count} ID:#{@request.id} #{@corp_list_url.id} #{@corp_list_url.url}"

      arrange_corporate_list

      if @limit_count <= @url_count
        @request.corporate_list_urls.where.not(arrange_status: RequestedUrl.arrange_statuses[:completed]).update_all(arrange_status: RequestedUrl.arrange_statuses[:completed])
        break
      end
    end

    @request.update!(list_site_result_headers: @data_combiner.headers.keys[0..300].to_json)
  end

  def arrange_corporate_list

    if @corp_list_url.arrange_status_completed?
      @url_count += @request.company_info_urls.where(corporate_list_url_id: @corp_list_url.id).size
      headers = Json2.parse(@corp_list_url.result.main)
      @data_combiner.count_headers(headers) if headers.present?
      @finish_status = :alredy_completed
      return
    end

    if @corp_list_url.arrange_status_error?
      @finish_status = :alredy_error
      raise ErrorStatusStop, "error ID: #{@corp_list_url.id}"
    end

    @request.company_info_urls.where(corporate_list_url_id: @corp_list_url.id).destroy_all
    ActiveRecord::Base.connection.close

    seeker = @data_combiner.combine_results(@corp_list_url)

    if seeker.blank?
      @corp_list_url.update!(arrange_status: RequestedUrl.arrange_statuses[:completed])
      @finish_status = :seeker_blank
      return
    end

    if seeker.headers.present?
      @corp_list_url.find_result_or_create(main: seeker.headers.to_json)
      @data_combiner.count_headers(seeker.headers)
    end

    @corp_list_url.find_result_or_create(main: seeker.combined_result.to_json) if @test_mode

    make_company_info_requested_urls(seeker.combined_result, seeker.new_urls)

    @corp_list_url.update!(arrange_status: RequestedUrl.arrange_statuses[:completed])
    ActiveRecord::Base.connection.close
    @finish_status = :normal_finish
  end

  def make_company_info_requested_urls(results, new_urls)
    if @test_mode
      @new_urls.concat(new_urls.values.flatten) if new_urls.present?
      return
    end

    all_get = first_page_all_get

    my_log.log "[#{Time.zone.now}][ResultArrangeWorker][#make_company_info_requested_urls]  result_count: #{results.count}  #{@corp_list_url.url}"

    ActiveRecord::Base.connection.close
    results.each_with_index do |(key, contents), idx|
      urls = new_urls[key].blank? ? [''] : new_urls[key]
      urls.each do |url|
        url = ( all_get && @limit_count <= @url_count ) ? '' : url.strip

        # バルクインサートに変更する方法を検討する
        SearchRequest::CompanyInfo.create_with_first_status_from_corporate_list(url: url,
                                                                                organization_name: contents[Analyzer::BasicAnalyzer::ATTR_ORG_NAME],
                                                                                result_corporate_list: contents.to_json,
                                                                                request_id: @request.id,
                                                                                corporate_list_url_id: @corp_list_url.id)
        ActiveRecord::Base.connection.close if idx%10 == 0
        @url_count += 1

        break if !all_get && @limit_count <= @url_count
      end
      break if !all_get && @limit_count <= @url_count
    end
  end

  def first_page_all_get
    @request.user.available?(:first_page_all_get) && @corp_list_url.url == @request.corporate_list_site_start_url
  end

  def test_option
    return unless @request.user.email == "abcdef#{Rails.application.credentials.user[:admin][:email]}"

    @new_urls = []
    @test_mode = true
  end

  def crawl_test_save_new_urls
    return unless @test_mode

    @request.update!(status: EasySettings.status.completed)

    key = "crawl_test #{@request.id} new_urls"
    Redis.new.multi do |pipeline|
      pipeline.set(key, @new_urls.to_json)
      pipeline.expire(key, 30*60)
    end
  end

  def my_log
    MyLog.new('my_crontab')
  end
end
