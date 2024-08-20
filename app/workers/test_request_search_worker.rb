class TestRequestSearchWorker
  include Sidekiq::Worker
  include AccessConcentrationGuardian
  include WorkerCommonUtil

  sidekiq_options queue: :test_request, retry: false

  def perform(request_id, *_tags) # _tagsは使わない。sidekiqの画面で分かりやすくするため。

    @req = Request.find_by_id(request_id)
    return if @req.blank? || !@req.test

    @requested_url = @req.requested_urls.first
    return if @requested_url.blank? || !@requested_url.test
    ActiveRecord::Base.connection.close

    sleep rand(30..60) if Rails.env.production? || Rails.env.dev?

    # 同じテストが走る時がある
    working_ids = Sidekiqer.new.get_working_test_request_ids
    return if working_ids.delete_if { |id| id != @req.id }.size > 1

    if @req.stop?
      @requested_url.discontinue
      ActiveRecord::Base.connection.close
    else

      res = execute_search

      if res[:status] == :sidekiq_rebooting
        @requested_url.renew
        # NoticeMailer.deliver_later(NoticeMailer.notice_simple("TEST\nREQ URL ID: #{@requested_url.id}\nTYPE:  #{@requested_url.type}\nPOSITION: #{res[:position]}", "TEST REQ URL #{@requested_url.id} POSITION: #{res[:position]}", 'クロール途中終了 Sidekiq再起動'))
        ActiveRecord::Base.connection.close
        return
      end

      if [:other_exec_now, :over_limit_working_analysis].include?(res[:status])
        @requested_url.rewaiting
        ActiveRecord::Base.connection.close
        return
      end

      @req.complete
      ActiveRecord::Base.connection.close

      begin
        if @req.registered_user?
          NoticeMailer.deliver_later(NoticeMailer.request_complete_mail_for_user(@req))
        else
          NoticeMailer.deliver_later(NoticeMailer.request_complete_mail(@req)) if @req.mail_address.present?
        end
      rescue => e
        Lograge.job_logging('WOKER', 'error', 'TestRequestSearchWorker', 'perform', { issue: 'Mail delivery Error', err_msg: e.message, backtrace: e.backtrace})
      end
    end
  end

  def execute_search

    @start_time = Time.zone.now

    log('info', {message: 'Start', requested_url: @requested_url.to_log})

    @requested_url.update!(status: EasySettings.status.working)
    return { status: :failure } unless @requested_url.corporate_list?

    ActiveRecord::Base.connection.close

    @url = @requested_url.url # ユーザ指定のURL

    if @req.list_site_analysis_result.blank?
      unless Url.correct_url_form?(@url)
        @requested_url.complete(EasySettings.finish_status.invalid_url)
        ActiveRecord::Base.connection.close
        log('info', { issue: "Invalid URL", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})
        return { status: :failure }
      end

      if Url.ban_domain?(url: @url)
        @requested_url.complete(EasySettings.finish_status.banned_domain)
        ActiveRecord::Base.connection.close
        log('info', { issue: "Banned Domain", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})
        return { status: :failure }
      end

      return { status: :failure } unless safety?

      @domain = Url.get_final_domain(@url) # アクセス可能なURL以外は全てnil

      return { status: :failure } unless exist_domain?

      return { status: :failure } if banned_domain?

      return { status: :failure } if sealed_page?(SealedPage.new(@domain))
    else
      @domain = Url.get_final_domain(@url) # アクセス可能なURL以外は全てnil
    end

    plan = @req.plan_name

    # all_working消える？
    @req.update!(status: EasySettings.status[:working])

    access_limit_count, analisys_page_limit = get_page_limit(plan)

    return { status: :sidekiq_rebooting, position: "execute_search 1" } if sidekiq_rebooting?

    cl = Crawler::CorporateList.new(@url, access_limit_count: access_limit_count,
                                          analisys_page_limit: analisys_page_limit,
                                          extraction_count_limit: EasySettings.corporate_list_extract_count_limit_each_page[plan],
                                          test: @req.test,
                                          tag: "TEST #{@req.id}",
                                          config: make_config)

    cl.set_base_url_path(@req.corporate_list_site_start_url)

    set_crawl_config(cl)

    if @req.list_site_analysis_result.present?
      analysis_result = Json2.parse(@req.list_site_analysis_result, symbolize: false)

    elsif @opt&.analysis_result.blank?

      # return { status: :over_limit_working_analysis } if Sidekiqer.new.over_limit_working_analysis_step_requests?(@req.id)

      analysis_result = cl.start_search_and_analysis_step

      raise 'サーチと解析のプロセスで失敗' if analysis_result.blank?

      return { status: :sidekiq_rebooting, position: "execute_search 2" } if sidekiq_rebooting?

      @req.update!(list_site_analysis_result: analysis_result.to_json)
    else
      analysis_result = Json2.parse(@opt&.analysis_result, symbolize: false)
      @req.update!(list_site_analysis_result: analysis_result.to_json)
    end

    cl.start_scraping_step(scraping_data: analysis_result)

    return { status: :sidekiq_rebooting, position: "execute_search 3" } if sidekiq_rebooting?

    ActiveRecord::Base.transaction do
      headers = DataCombiner.new(request: @req).count_headers(cl.seeker.headers)

      @req.update!(accessed_urls: cl.accessed_urls.to_json,
                   complete_multi_path_analysis: cl.seeker.complete_multi_path_analysis,
                   multi_path_candidates: cl.seeker.multi_path_candidates.to_json,
                   multi_path_analysis: cl.seeker.multi_path_analysis.to_json,
                   list_site_result_headers: headers.to_json)

      @requested_url.find_result_or_create(corporate_list: cl.result.to_json)
    end


    @requested_url.complete(EasySettings.finish_status.successful, @domain)
    ActiveRecord::Base.connection.close

    log('info', { issue: "Normal Finish", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})

    { status: :success }
  rescue => e
    log('error', { requested_url: @requested_url.to_log, err_msg: e.message, backtrace: e.backtrace })

    return { status: :sidekiq_rebooting, position: "execute_search error 4" } if sidekiq_rebooting?

    @requested_url.update!(status: EasySettings.status.error, finish_status: EasySettings.finish_status.error)

    delete_current_mark

    return { status: :error, response: e }
  end

  private

  def log(level = 'info', contents = {})
    Lograge.job_logging('WOKER', level, 'TestRequestSearchWorker', 'execute_search', contents)
  end
end
