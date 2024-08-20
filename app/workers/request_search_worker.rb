class RequestSearchWorker
  include Sidekiq::Worker
  include AccessConcentrationGuardian
  include WorkerCommonUtil

  sidekiq_options queue: :request, retry: EasySettings.retry_count

  sidekiq_retry_in do |count, exception|
    300 * (count ** 2)
  end

  def perform(requested_url_id, *_tags) # _tagsは使わない。sidekiqの画面で分かりやすくするため。

    return if Memory.current < 700 && Memory.average(count: 5, interval: 3) < 800

    @requested_url = RequestedUrl.find_by_id(requested_url_id)
    return if @requested_url.blank? || @requested_url.test

    @req = @requested_url.request.reload
    ActiveRecord::Base.connection.close

    # URLの検証（検証後に削除しても良い）
    a = Url.escape(@requested_url.url)
    b = Url.escape(a)
    if a != b
      NoticeMailer.deliver_later(NoticeMailer.notice_simple("URL検証 エスケープの違い\n#{@requested_url.url}\n#{a}\n#{b}"))
    end
    ################################

    test_option

    if @req.stop?
      @requested_url.discontinue
      ActiveRecord::Base.connection.close
    else

      res = if @requested_url.finished?
        {}
      elsif @requested_url.type == SearchRequest::CorporateSingle::TYPE
        execute_corporate_list_single_search
      elsif @requested_url.type == SearchRequest::CorporateList::TYPE && @req.list_site_analysis_result.present?
        execute_corporate_list_multi_search
      else
        execute_search
      end

      if res[:status] == :sidekiq_rebooting
        @requested_url.renew
        @req.set_working
        # NoticeMailer.deliver_later(NoticeMailer.notice_simple("REQ URL ID: #{@requested_url.id}\nTYPE:  #{@requested_url.type}\nPOSITION: #{res[:position]}", "REQ URL #{@requested_url.id} POSITION: #{res[:position]}", 'クロール途中終了 Sidekiq再起動'))
        ActiveRecord::Base.connection.close
        return
      end

      if [:other_exec_now, :over_limit_working_analysis].include?(res[:status])
        delete_current_mark
        @requested_url.renew
        @req.set_working
        ActiveRecord::Base.connection.close
        return
      end

      # 完了処理はTasks::WorkersHandler.executeで行う

      # リトライさせるためにraiseする
      raise res[:response] if res[:status] == :retry_error
    end
  end

  private

  def execute_search

    @start_time = Time.zone.now

    log('info', 'execute_search', {message: 'Start', requested_url: @requested_url.to_log})

    @requested_url.update!(status: EasySettings.status.working)
    @free_search         = @req.free_search
    @free_search_option  = @req.free_search_option
    @corporate_list      = @requested_url.corporate_list?

    ActiveRecord::Base.connection.close

    return { status: :failure } if over_monthly_limit?

    @url = @requested_url.url # ユーザ指定のURL

    unless Url.correct_url_form?(@url)
      @requested_url.complete(EasySettings.finish_status.invalid_url)
      ActiveRecord::Base.connection.close
      log('info', 'execute_search', { issue: "Invalid URL", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})
      return { status: :failure }
    end

    if Url.ban_domain?(url: @url)
      @requested_url.complete(EasySettings.finish_status.banned_domain)
      ActiveRecord::Base.connection.close
      log('info', 'execute_search', { issue: "Banned Domain", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})
      return { status: :failure }
    end

    # 一次ドメイン判定
    # access_recordに記録がある場合はそれを使用する
    # unless @free_search || @corporate_list
    #   if @requested_url.fetch_access_record
    #     ActiveRecord::Base.connection.close
    #     log('info', 'execute_search', { issue: "Already Fetched By Initial Domain", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})

    #     return { status: :success }
    #   end
    # end

    return { status: :failure } if @crawl_test_mode.nil? && !safety?

    @url = Url.check_http_or_https(@url) if @req.company_db_search?

    @domain = Url.get_final_domain(@url) # アクセス可能なURL以外は全てnil。get_final_domainでもまだ無理なことがある。

    if @req.company_db_search? && @domain.nil? && Url.not_exist_page?(@url)
      Company.find_by(domain: Url.get_domain(@url))&.destroy
    end

    return { status: :failure } unless exist_domain?

    return { status: :failure } if banned_domain?

    return { status: :failure } if sealed_page?(SealedPage.new(@domain))

    return { status: :success } if use_access_record?

    return { status: :sidekiq_rebooting, position: "execute_search 1" } if sidekiq_rebooting?

    if @corporate_list

      return { status: :other_exec_now } if exec_other_request_now?

      add_execute_log(:start)

      plan = @req.plan_name

      access_limit_count, analisys_page_limit = get_page_limit(plan)

      cl = Crawler::CorporateList.new(@url, access_limit_count: access_limit_count,
                                            analisys_page_limit: analisys_page_limit,
                                            extraction_count_limit: EasySettings.corporate_list_extract_count_limit_each_page[plan],
                                            test: @req.test,
                                            tag: "#{@req.test ? 'TEST' : 'MAIN'} #{@req.id} #{@requested_url.id}",
                                            config: make_config)

      cl.set_base_url_path(@req.corporate_list_site_start_url)

      set_crawl_config(cl)

      if @opt&.analysis_result.blank?
        # return { status: :over_limit_working_analysis } if Sidekiqer.new.over_limit_working_analysis_step_requests?(@req.id)

        analysis_result = cl.start_search_and_analysis_step

        raise 'サーチと解析のプロセスで失敗' if analysis_result.blank?

        return { status: :sidekiq_rebooting, position: "execute_search analysis_end 2" } if sidekiq_rebooting?
      else
        analysis_result = Json2.parse(@opt&.analysis_result, symbolize: false)
      end

      @req.update!(list_site_analysis_result: analysis_result.to_json)
      ActiveRecord::Base.connection.close

      cl.start_scraping_step_to_multi_urls(urls: [@url], scraping_data: analysis_result)

      delete_current_mark

      return { status: :failure } if over_monthly_limit?

      record_multi_crawl_result(cl)

    else
      add_execute_log(:start)

      access_record = AccessRecord.new(@domain)

      ar_count = access_record.exist? && access_record.have_result? ? access_record.count + 1 : 1
      access_record.add_new_item({count: ar_count, last_access_date: Time.zone.now})

      # 会社情報をクロール
      cf = search_company_info(access_record)

      return { status: :sidekiq_rebooting, position: "execute_search compay_search end 4" } if sidekiq_rebooting?

      if cf == :unobtainable_doc_with_unrepeatable ||
         cf == :corporate_search_error
        return { status: :sidekiq_rebooting, position: "execute_search compay_search error_end1 5" } if sidekiq_rebooting?
        finish_status = cf == :corporate_search_error ? EasySettings.finish_status.error : EasySettings.finish_status.unexist_page
        @requested_url.complete(finish_status, @domain)
        return { status: :failure }

      elsif cf == :unobtainable_doc_error
        return { status: :sidekiq_rebooting, position: "execute_search compay_search error_end2 6" } if sidekiq_rebooting?
        count_up_retry(EasySettings.finish_status.network_error)
        return { status: :failure } if @requested_url.status == EasySettings.status.error
        return { status: :retry_error, response: Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocError }
      end

      if cf.change_url
        @url = cf.url.unescaped_url
        @domain = cf.url.domain
        access_record = AccessRecord.new(@domain)
      end

      # 情報を取得できなかった時
      return { status: :failure } unless got_info?(cf, access_record)

      free_search_result = @free_search ? cf.optional_result.to_json : nil

      cd = CompanyData.new(@url, cf.result2)

      record_company_info_result(cf, cd, access_record, free_search_result)
    end

    log('info', 'execute_search', { issue: "Normal Finish", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})

    { status: :success }

  rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, ActiveRecord::ConnectionNotEstablished => e
    log('error', 'execute_search', { issue: 'MySQL error', requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    return { status: :retry_error, response: e }
  rescue => e
    log('error', 'execute_search', { requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    delete_current_mark if @corporate_list

    return { status: :sidekiq_rebooting, position: "execute_search error_end 7" } if sidekiq_rebooting?

    count_up_retry
    return { status: :failure } if @requested_url.status == EasySettings.status.error
    return { status: :retry_error, response: e }
  end

  def record_company_info_result(crawler, company_data, access_record, free_search_result)
    err_count ||= 0

    ActiveRecord::Base.transaction do
      @requested_url.find_result_or_create(free_search: free_search_result, main: company_data.clean_data.to_json)
      @req.update_company_info_result_headers(@requested_url)
    end
    ActiveRecord::Base.connection.close

    access_record.create({name: company_data.name, title: crawler.page_title, result: company_data.clean_data, last_fetch_date: Time.zone.now,
                          urls: crawler.target_page_urls, accessed_urls: crawler.accessed_urls
                         })
    crawler.release

    CompanyCompanyGroup.create_main_connections(@domain, company_data)

    update_monthly_count_and_complete_for_company_info

    if err_count > 0
      NoticeMailer.notice_simple("MySQLエラー突破 record_company_info_result #{err_count}\n requested_url: #{@requested_url.to_log}", 'record_company_info_result', 'MySQLエラー突破').deliver_now
    end

  # 並行稼働を増やすほど、気にしないと行けなくなる。RDSのインスタンスタイプを上げることも検討する。
  rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, ActiveRecord::ConnectionNotEstablished => e
    err_count += 1
    log('error', 'record_company_info_result', { issue: "MySQL Error count #{err_count}", requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    NoticeMailer.notice_simple("MySQLエラー record_company_info_result #{err_count}\n requested_url: #{@requested_url.to_log}\n#{e.class}\n#{e.message}\n#{e.backtrace}", 'record_company_info_result エラー発生', 'MySQLエラー').deliver_now

    ActiveRecord::Base.connection.close
    sleep 1
    retry if err_count < 20
    raise e.class, e.message
  end

  def update_monthly_count_and_complete_for_company_info
    if @req.corporate_list_site? || @req.plan == EasySettings.plan[:public]
      @requested_url.complete(EasySettings.finish_status.successful, @domain)
      ActiveRecord::Base.connection.close
      return
    end

    ActiveRecord::Base.transaction do
      @requested_url.complete_with_updating_acquisition_count(1, EasySettings.finish_status.successful, @domain) do |over|
        @requested_url.find_result_or_create(free_search: nil, main: nil) if over
      end
    end
    ActiveRecord::Base.connection.close
  end

  # マルチ
  def execute_corporate_list_multi_search
    @start_time = Time.zone.now

    return { status: :failure } if over_monthly_limit?

    log('info', 'execute_corporate_list_multi_search', {message: 'Start #execute_corporate_list_multi_search', requested_url: @requested_url.to_log})

    @requested_url.update!(status: EasySettings.status.working)

    ActiveRecord::Base.connection.close

    @url = @requested_url.url # ユーザ指定のURL
    @domain = @req.corporate_list_domain || Url.get_final_domain(@url)

    return { status: :failure } unless exist_domain?

    return { status: :other_exec_now } if exec_other_request_now?

    return { status: :sidekiq_rebooting, position: "multi start 8" } if sidekiq_rebooting?

    add_execute_log(:start)

    analysis_result = Json2.parse(@req.list_site_analysis_result, symbolize: false)
    accessed_urls   = Json2.parse(@req.reload.accessed_urls, symbolize: false)

    plan = @req.plan_name

    access_limit_count, analisys_page_limit = get_page_limit(plan)

    cl = Crawler::CorporateList.new(@url, access_limit_count: access_limit_count,
                                          analisys_page_limit: analisys_page_limit,
                                          extraction_count_limit: EasySettings.corporate_list_extract_count_limit_each_page[plan],
                                          tag: "MAIN #{@req.id} #{@requested_url.id}",
                                          config: make_config)

    cl.set_accessed_records(accessed_urls: accessed_urls) if accessed_urls.present?
    cl.set_base_url_path(@req.corporate_list_site_start_url)

    cl.seeker.set_multi_path_analysis(complete_multi_path_analysis: @req.reload.complete_multi_path_analysis,
                                      multi_path_candidates: Json2.parse(@req.multi_path_candidates, symbolize: false),
                                      multi_path_analysis: Json2.parse(@req.multi_path_analysis, symbolize: false))

    cl.start_scraping_step_to_multi_urls(urls: [@url], scraping_data: analysis_result)

    delete_current_mark

    return { status: :failure } if over_monthly_limit?

    record_multi_crawl_result(cl)

    log('info', 'execute_corporate_list_multi_search', { issue: "Normal Finish", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})

    { status: :success }

  rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, ActiveRecord::ConnectionNotEstablished => e
    log('error', 'execute_corporate_list_multi_search', { issue: 'MySQL Error', requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    return { status: :retry_error, response: e }
  rescue => e
    log('error', 'execute_corporate_list_multi_search', { requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    delete_current_mark

    return { status: :sidekiq_rebooting, position: "multi error_end 10" } if sidekiq_rebooting?

    count_up_retry

    return { status: :retry_error, response: e }
  end

  def record_multi_crawl_result(crawler)
    err_count ||= 0

    MyLog.new('retry').log "[#{Time.zone.now}][RequestSearchWorker][#record_multi_crawl_result] 1 ID:#{@requested_url.id} count: #{err_count}" if err_count > 0

    @req.update_multi_path_analysis(complete_multi_path_analysis: crawler.seeker.complete_multi_path_analysis,
                                    multi_path_candidates: crawler.seeker.multi_path_candidates,
                                    multi_path_analysis: crawler.seeker.multi_path_analysis)
    ActiveRecord::Base.connection.close

    accessed_urls = @req.reload.update_accessed_urls(crawler.accessed_urls)
    ActiveRecord::Base.connection.close

    @result_count = count_finished_result
    cut_result_by_excel_limit(crawler_corporate_list: crawler, excel_limit: EasySettings.excel_row_limit[@req.plan_name])

    target_url_result = crawler.result[@url] || {result: {}, candidate_crawl_urls: []}

    process_result(target_url_result[:result])

    @requested_url.find_result_or_create(corporate_list: ( target_url_result[:result] || {} ).to_json)

    candidate_crawl_urls = if @req.only_this_page? || EasySettings.excel_row_limit[@req.plan_name] <= @result_count
      []
    else
      filtered_candidate_crawl_urls(crawler_corporate_list: crawler,
                                    candidate_crawl_urls: target_url_result[:candidate_crawl_urls],
                                    accessed_urls: accessed_urls)
    end

    unless @req.reload.stop?
      make_list_requested_urls(candidate_crawl_urls: candidate_crawl_urls)
    end

    @got_single_urls = crawler.single_urls

    update_monthly_count_and_complete_for_multi

    if err_count > 0
      MyLog.new('retry').log "[#{Time.zone.now}][RequestSearchWorker][#record_multi_crawl_result] 5 ID:#{@requested_url.id} count: #{err_count}"
    end

  # 並行稼働を増やすほど、気にしないと行けなくなる。RDSのインスタンスタイプを上げることも検討する。
  rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, ActiveRecord::ConnectionNotEstablished => e
    err_count += 1
    log('error', 'record_multi_crawl_result', { issue: "MySQL Error count #{err_count}", requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    NoticeMailer.notice_simple("MySQLエラー record_multi_crawl_result #{err_count}\n requested_url: #{@requested_url.to_log}\n#{e.class}\n#{e.message}\n#{e.backtrace}", 'record_multi_crawl_result エラー発生', 'MySQLエラー').deliver_now if err_count > 10

    MyLog.new('retry').log "[#{Time.zone.now}][RequestSearchWorker][#record_multi_crawl_result] 0 ID:#{@requested_url.id} count: #{err_count}"


    ActiveRecord::Base.connection.close
    sleep ( err_count > 5 ? rand(1.0..4.0) : 1 )
    retry if err_count < 20
    raise e.class, e.message
  end

  def update_monthly_count_and_complete_for_multi
    if @req.plan == EasySettings.plan[:public]
      make_single_requested_urls unless @req.reload.stop?
      @req.set_working
      @requested_url.complete(EasySettings.finish_status.successful, @domain)
      ActiveRecord::Base.connection.close
      return
    end

    result = Json2.parse(@requested_url.corporate_list_result, symbolize: false)
    result_size = ( result['result']&.size || 0 ) + ( result['table_result']&.size || 0 )
    limit = EasySettings.monthly_acquisition_limit[@req.plan_name]

    ActiveRecord::Base.transaction do
      @requested_url.complete_with_updating_acquisition_count(result_size, EasySettings.finish_status.successful, @domain) do |over, total_count|
        if over
          @requested_url.find_result_or_create(corporate_list: nil)
        else
          cut_result_by_monthly_limit(result: result, limit: limit, total_count: total_count)
        end

        @req.set_working
      end
    end
    ActiveRecord::Base.connection.close
  end

  # シングル
  # 冪等処理
  def execute_corporate_list_single_search
    @start_time = Time.zone.now

    log('info', 'execute_corporate_list_single_search', {message: 'Start #execute_corporate_list_single_search', requested_url: @requested_url.to_log})

    @requested_url.update!(status: EasySettings.status.working)
    @corporate_list = @requested_url.corporate_list?

    ActiveRecord::Base.connection.close

    @url = @requested_url.url # ユーザ指定のURL
    @domain = @req.corporate_list_domain || Url.get_final_domain(@url)

    return { status: :failure } unless exist_domain?

    return { status: :other_exec_now } if exec_other_request_now?

    return { status: :sidekiq_rebooting, position: "single start 11" } if sidekiq_rebooting?

    add_execute_log(:start)

    analysis_result = Json2.parse(@req.list_site_analysis_result, symbolize: false)
    accessed_urls   = Json2.parse(@req.reload.accessed_urls, symbolize: false)

    plan = @req.plan_name

    access_limit_count, analisys_page_limit = get_page_limit(plan)

    cl = Crawler::CorporateList.new(@url, access_limit_count: access_limit_count,
                                          analisys_page_limit: analisys_page_limit,
                                          extraction_count_limit: EasySettings.corporate_list_extract_count_limit_each_page[plan],
                                          tag: "#{@req.test ? 'TEST' : 'MAIN'} #{@req.id} #{@requested_url.id}",
                                          config: make_config)

    cl.set_base_url_path(@req.corporate_list_site_start_url)

    cl.start_scraping_step_to_single_urls(urls: @url, scraping_data: analysis_result)

    record_single_crawl_result(cl)

    log('info', 'execute_corporate_list_single_search', { issue: "Normal Finish", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})

    { status: :success }

  rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, ActiveRecord::ConnectionNotEstablished => e
    log('error', 'execute_corporate_list_single_search', { issue: 'mysql connection error', requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    return { status: :retry_error, response: e }
  rescue => e
    log('error', 'execute_corporate_list_single_search', { requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    return { status: :sidekiq_rebooting, position: "single error end 13" } if sidekiq_rebooting?

    count_up_retry

    return { status: :retry_error, response: e }
  end

  def record_single_crawl_result(crawler)
    err_count ||= 0

    process_result(crawler.result)

    @requested_url.find_result_or_create(corporate_list: crawler.result.to_json)

    @requested_url.complete(EasySettings.finish_status.successful, @domain)
    ActiveRecord::Base.connection.close

    if err_count > 0
      NoticeMailer.notice_simple("MySQLエラー突破 record_single_crawl_result #{err_count}\n requested_url: #{@requested_url.to_log}", 'record_single_crawl_result', 'MySQLエラー突破').deliver_now
    end

  # 並行稼働を増やすほど、気にしないと行けなくなる。RDSのインスタンスタイプを上げることも検討する。
  rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, ActiveRecord::ConnectionNotEstablished => e
    err_count += 1
    log('error', 'record_single_crawl_result', { issue: "mysql connection error count #{err_count}", requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    NoticeMailer.notice_simple("MySQLエラー record_single_crawl_result #{err_count}\n requested_url: #{@requested_url.to_log}\n#{e.class}\n#{e.message}\n#{e.backtrace}", 'record_single_crawl_result エラー発生', 'MySQLエラー').deliver_now if err_count > 10

    ActiveRecord::Base.connection.close
    sleep ( err_count > 5 ? rand(1.0..4.0) : 1 )
    retry if err_count < 20
    raise e.class, e.message
  end

  def process_result(result)
    @opt ||= select_crawl_options(@domain)
    if @opt.present? && @opt.process_result
      begin
        @opt.class_name.constantize.process_result(result, @requested_url.type)
      rescue => e
        log('error', 'process_result', { issue: "Process Result Error", requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
      end
    end
  end

  def count_up_retry(finish_status = EasySettings.finish_status.error)
    @requested_url.count_up_retry
    status = if @requested_url.retry_count >= EasySettings.retry_count + 1
      EasySettings.status.error
    else
      EasySettings.status.retry
    end
    @requested_url.update!(status: status, finish_status: finish_status)
  end

  def count_finished_result
    count = 0
    @req.reload.corporate_list_urls.success.main.each do |list_url|
      results = Json2.parse(list_url.corporate_list_result, symbolize: false)
      count += current_result_count(result: results)
    end
    count
  end

  def current_result_count(result:)
    return 0 if result.blank?

    multi_result = result['result'] || result[:result]
    multi_table_result = result['table_result'] || result[:table_result]

    if multi_result.present? && multi_table_result.present?
      return ( multi_result.keys + multi_table_result.keys ).uniq.size
    elsif multi_result.present?
      return multi_result.size
    elsif multi_table_result.present?
      return multi_table_result.size
    else
      0
    end
  end

  def use_access_record?
    return false if @corporate_list || @free_search

    if @requested_url.fetch_access_record(domain: @domain)

      ActiveRecord::Base.connection.close
      log('info', 'use_access_record?', { issue: "Already Fetched By Final Domain", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})
      return true
    end

    false
  end

  def filtered_candidate_crawl_urls(crawler_corporate_list:, candidate_crawl_urls:, accessed_urls:)
    return nil if @req.test

    return nil if candidate_crawl_urls.blank?

    req_urls = @req.corporate_list_urls&.pluck(:url)

    urls = []
    candidate_crawl_urls.each_with_index do |url, idx|
      next if url.blank?
      next if Url.include?(accessed_urls, url)
      next if Url.include?(req_urls, url)
      next if crawler_corporate_list.seeker.complete_multi_path_analysis && !crawler_corporate_list.seeker.match_with_comparing_paths?(url)

      urls << url
    end
    urls.blank? ? nil : urls
  end

  def cut_result_by_excel_limit(crawler_corporate_list:, excel_limit:)
    limit_touched_url = nil

    first_page_all_get = first_page_all_get?

    crawler_corporate_list.result.each_with_index do |(tmp_url, tmp_result), i|

      @result_count += current_result_count(result: tmp_result[:result])

      if excel_limit <= @result_count

        limit_touched_url = tmp_url

        cb_res = Crawler::Seeker.new.combine_multi_results(multi_result: tmp_result[:result][:result], multi_table_result: tmp_result[:result][:table_result])

        leave_keys = cb_res.keys[0..(cb_res.keys.size - @result_count + excel_limit - 1)] # 残すキー
        cb_res.delete_if { |k, v| !leave_keys.include?(k) }
        leave_single_urls = cb_res.map { |k,v| v[Analyzer::BasicAnalyzer::ATTR_CONTENT_URL] }.flatten # 残すsingle_urls

        if !first_page_all_get || i > 0
          crawler_corporate_list.result[tmp_url][:result][:result].delete_if       { |k, v| !leave_keys.include?(k) }
          crawler_corporate_list.result[tmp_url][:result][:table_result].delete_if { |k, v| !leave_keys.include?(k) }
        end
        crawler_corporate_list.single_urls[tmp_url].delete_if { |url| !leave_single_urls.include?(url) }

      elsif limit_touched_url.present?
        crawler_corporate_list.result.delete_if      { |url, v| url == tmp_url }
        crawler_corporate_list.single_urls.delete_if { |url, v| url == tmp_url }
      end
    end
  end

  def cut_result_by_monthly_limit(result:, limit:, total_count:)
    @deletable_single_urls = []
    @leave_single_urls     = []

    if limit < total_count

      cut_count = total_count - limit

      first_page_all_get = first_page_all_get?

      if result['table_result'].size >= cut_count
        delete_keys = result['table_result'].keys[cut_count*-1..-1] # 後ろから削除する

        extract_deletable_single_urls(result['table_result'], delete_keys)

        if first_page_all_get
          result['table_result'] = remove_new_domain_urls(result: result['table_result'], delete_keys: delete_keys)
        else
          result['table_result'].delete_if { |k, v| delete_keys.include?(k) }
        end
        cut_count = 0
      else
        cut_count = cut_count - result['table_result'].size

        extract_deletable_single_urls(result['table_result'], result['table_result'].keys)

        # 全消し
        if first_page_all_get
          result['table_result'] = remove_new_domain_urls(result: result['table_result'])
        else
          result['table_result'] = {}
        end
      end

      if cut_count > 0
        if result['result'].size >= cut_count
          delete_keys = result['result'].keys[cut_count*-1..-1] # 後ろから削除する

          extract_deletable_single_urls(result['result'], delete_keys)

          if first_page_all_get
            result['result'] = remove_new_domain_urls(result: result['result'], delete_keys: delete_keys)
          else
            result['result'].delete_if { |k, v| delete_keys.include?(k) }
          end
        else
          # 現在のロジックではこの場合わけルートはありえない

          extract_deletable_single_urls(result['result'], result['result'].keys)

          # 全消し
          if first_page_all_get
            result['result'] = remove_new_domain_urls(result: result['result'])
          else
            result['result'] = {}
          end
        end
      else
        extract_deletable_single_urls(result['result'], [])
      end

      @deletable_single_urls.delete_if { |url| @leave_single_urls.include?(url) }

      @requested_url.find_result_or_create(corporate_list: result.to_json)
    end

    unless @req.reload.stop?
      make_single_requested_urls
    end
  end

  def remove_new_domain_urls(result:, delete_keys: nil)
    result.each do |k, v|
      next if delete_keys.present? && !delete_keys.include?(k)
      v[Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL] = []
      result[k] = v
    end
    result
  end

  def extract_deletable_single_urls(result, delete_keys)
    dels   = []
    leaves = []
    result.each do |k, v|
      if delete_keys.include?(k)
        dels << v[Analyzer::BasicAnalyzer::ATTR_CONTENT_URL]
      else
        leaves << v[Analyzer::BasicAnalyzer::ATTR_CONTENT_URL]
      end
    end

    @deletable_single_urls = @deletable_single_urls.concat(dels.flatten).uniq
    @leave_single_urls     = @leave_single_urls.concat(leaves.flatten).uniq
  end

  def first_page_all_get?
    @req.user.available?(:first_page_all_get) &&
    @requested_url.url == @req.corporate_list_site_start_url
  end

  def over_monthly_limit?
    return false if @req.plan == EasySettings.plan[:public]
    return false if @req.corporate_list_site? && @requested_url.company_info?

    if EasySettings.monthly_acquisition_limit[@req.plan_name] <= MonthlyHistory.find_around(@req.user, @req.created_at).reload.acquisition_count
      @requested_url.complete(EasySettings.finish_status.monthly_limit, @domain)
      return true
    end
    false
  end

  def make_multi_requested_urls(crawler_corporate_list:, accessed_urls:)
    return if @req.test

    req_urls = @req.corporate_list_urls&.pluck(:url)

    crawler_corporate_list.candidate_crawl_urls.each_with_index do |url, idx|
      next if url.blank?
      next if Url.include?(accessed_urls, url)
      next if Url.include?(req_urls, url)
      next if crawler_corporate_list.seeker.complete_multi_path_analysis && !crawler_corporate_list.seeker.match_with_comparing_paths?(url)
      SearchRequest::CorporateList.create_with_first_status(url: url.strip, request_id: @req.id)

      ActiveRecord::Base.connection.close if idx%1_000 == 0
    end
  end

  def make_single_requested_urls
    return if @req.test

    @deletable_single_urls ||= []

    single_urls = @req.corporate_single_urls&.pluck(:url, :id).to_h

    @got_single_urls.each do |m_url, s_urls|
      next unless @url == m_url
      single_url_ids = []
      s_urls.each_with_index do |url, i|
        next if url.blank?
        next if @crawl_test_mode && !match_test_single_url_condition?(url)
        next if @crawl_test_mode && i > @crawl_test_single_max

        #すでに存在するsingle_urlsとのマッチ
        if ( matched_url = Url.extract_matched_url(single_urls, url) ).present?
          single_url_ids << matched_url.values[0]
          next
        end

        next if @deletable_single_urls.include?(url)

        single_url = SearchRequest::CorporateSingle.create_with_first_status(url: url.strip, request_id: @req.id)

        single_url_ids << single_url.id
        MyLog.new('validate_check').log "[#{Time.zone.now}] SINGLE作成 URL:#{url.strip} ID:#{single_url.id} FROM:#{@requested_url.id} FROM_URL:#{@requested_url.url}"
      end

      req_url = @req.corporate_list_urls.where(url: m_url).main.first&.update_single_url_ids(single_url_ids)

      ActiveRecord::Base.connection.close
    end
  end

  def make_list_requested_urls(candidate_crawl_urls:)
    return if @req.test
    return if candidate_crawl_urls.blank?
    return if @req.corporate_list_urls.main.size >= EasySettings.corporate_list_search_page_limit[@req.plan_name]

    list_urls = @req.corporate_list_urls&.pluck(:url, :id).to_h

    candidate_crawl_urls.each do |url|
      url = url.strip
      next if url.blank?

      break if @req.corporate_list_urls.main.size >= EasySettings.corporate_list_search_page_limit[@req.plan_name]

      # すでに存在するlist_urlsとのマッチ
      if ( matched_url = Url.extract_matched_url(list_urls, url) ).present?
        next
      end

      list = SearchRequest::CorporateList.create_with_first_status(url: url, request_id: @req.id, test: false)
      ActiveRecord::Base.connection.close

      MyLog.new('validate_check').log "[#{Time.zone.now}] LIST作成 URL:#{url} ID:#{list.id} FROM:#{@requested_url.id} FROM_URL:#{@requested_url.url}"
    end

    ActiveRecord::Base.connection.close
  end

  def search_company_info(access_record)
    cf = Crawler::Corporate.new(@url, supporting_urls: access_record.supporting_urls, option: @free_search_option, tag: "CI #{@req.id} #{@requested_url.id}")
    cf.start
    cf
  rescue Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocWithUnrepeatableError => e
    :unobtainable_doc_with_unrepeatable

  rescue Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocError => e
    :unobtainable_doc_error

  # リトライしない & お知らせする
  rescue => e
    log('info', 'search_company_info', { requested_url: @requested_url.to_log, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    contents = "[#{Time.zone.now}] [requested_url: #{@requested_url.to_log}] [err_class: #{e.class}] [err_msg: #{e.message}] [backtrace: ] #{e.backtrace}"
    # NoticeMailer.deliver_later(NoticeMailer.notice_error(contents, 'クローラサーチエラー', 'error'.downcase))
    MyLog.new('crawl_alert').log "[#{Time.zone.now}] クローラサーチエラー #{contents}"
    :corporate_search_error
  end

  def got_info?(crawl_force, access_record)
    return true unless crawl_force.can_not_get_info?

    # 情報を取得できなかった時
    if crawl_force.seal_page_flag && access_record.count == 1
      SealedPage.new(@domain).register
      access_record = nil
    end

    @requested_url.complete(EasySettings.finish_status.can_not_get_info)
    ActiveRecord::Base.connection.close
    log('info', 'got_info?', { issue: "Can Not Get Info Finish", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})
    false
  end

  def log(level = 'info', method = 'execute_search', contents = {})
    Lograge.job_logging('WOKER', level, 'RequestSearchWorker', method, contents)
  end

  def test_option
    return unless @req.user.email == "abcdef#{Rails.application.credentials.user[:admin][:email]}"

    @make_excel_skip = true
    @crawl_test_mode = true
    @crawl_test_single_max = 20
  end

  # テストなので、クロール時間を削減するために入れている。queueモードだと全てのsingleを実行してしまうので。
  # これまでは、singleは日本語にしてたので、有効であったが、最近はsingleに日本語を含まないケースも出てくる
  def match_test_single_url_condition?(url)
    if ['bigcompany', 'en_tenshoku', 'saiben', 'hinata-spot'].select { |keyword| url.include?(keyword) }.present?
      set_crawl_test_single_max(url)
      true
    else
      url.match?(/(?:\p{Hiragana}|\p{Katakana}|[ー－]|[一-龠々])+/)
    end
  end

  def set_crawl_test_single_max(url)
    @crawl_test_single_max = 6 if url.include?('bigcompany')
    @crawl_test_single_max = 17 if url.include?('en_tenshoku')
    @crawl_test_single_max = 3 if url.include?('hinata-spot')
  end

  def add_execute_log(mode = :start)
    return if mode != :start && !@log_start

    if mode == :start
      @log_start = true
      @log_start_time = Time.zone.now
      duration = ''
    else
      duration = "[DURATION: #{(Time.zone.now - @log_start_time).floor(1)} sec]"
    end

    text = "[#{Time.zone.now.strftime("%Y-%m-%d %H:%M:%S %:z")}][#{mode == :start ? 'START' : ' END '}] [Mem free: #{Memory.current_free} M] [Mem: #{Memory.current} M] ID:#{@req.id} URL_ID:#{@requested_url.id} URL:#{@requested_url.url} #{duration}"
    File.open("log/request_execute_#{Time.zone.now.strftime("%Y%m%d")}.log", mode = "a") do |f|
      f.write(text + "\n")
    end
  end
end
