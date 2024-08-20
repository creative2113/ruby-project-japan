class SearchWorker
  include Sidekiq::Worker
  sidekiq_options queue: :search, retry: false

  def perform(search_request_id)

    search_req = SearchRequest.find(search_request_id)
    url        = search_req.url
    domain     = search_req.domain
    ActiveRecord::Base.connection.close

    if search_req.finished?
      return
    end

    start_time = Time.zone.now

    Lograge.job_logging('WOKER', 'info', 'SearchWorker', 'perform', {message: 'Start', search_request: search_req.to_log})

    search_req.update!(status: EasySettings.status.working)
    free_search        = search_req.free_search
    free_search_option = search_req.free_search_option

    ActiveRecord::Base.connection.close

    access_record = AccessRecord.new(domain).get

    unless access_record.exist? && access_record.have_result?
      access_record.add_new_item({count: 1, last_access_date: Time.zone.now})
    end

    cf = search_company_info(url, access_record, free_search_option, search_req)

    if cf == :unobtainable_doc_with_unrepeatable ||
       cf == :corporate_search_error
      finish_status = cf == :corporate_search_error ? EasySettings.finish_status.error : EasySettings.finish_status.unexist_page
      search_req.complete(finish_status)
      return { status: :failure }

    elsif cf == :unobtainable_doc_error
      search_req.complete(EasySettings.finish_status.network_error)
      return { status: :error, response: Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocError }
    end

    if cf.change_url
      url = cf.url.unescaped_url
      domain = cf.url.domain
      access_record = AccessRecord.new(domain)
    end

    # 情報を取得できなかった時
    if cf.can_not_get_info?
      if cf.seal_page_flag && access_record.count == 1
        SealedPage.new(domain).register
        access_record = nil
      end

      search_req.complete(EasySettings.finish_status.can_not_get_info)
      ActiveRecord::Base.connection.close
      Lograge.job_logging('WOKER', 'info', 'SearchWorker', 'perform', { issue: "Can Not Get Info Finish", process_time: Time.zone.now - start_time, search_request: search_req.to_log})

      return
    end

    if free_search
      search_req.update!(free_search_result: cf.optional_result.to_json)
      ActiveRecord::Base.connection.close
    end

    cd = CompanyData.new(url, cf.result2)

    access_record.create({name: cd.name, title: cf.page_title, result: cd.clean_data, last_fetch_date: Time.zone.now,
                          urls: cf.target_page_urls, accessed_urls: cf.accessed_urls
                         })
    cf.release

    CompanyCompanyGroup.create_main_connections(domain, cd)

    search_req.complete(EasySettings.finish_status.successful, access_record.domain)
    ActiveRecord::Base.connection.close

    Lograge.job_logging('WOKER', 'info', 'SearchWorker', 'perform', { issue: "Normal Finish", process_time: Time.zone.now - start_time, search_request: search_req.to_log})

  rescue => e
    Lograge.job_logging('WOKER', 'fatal', 'SearchWorker', 'perform', { search_request: search_req.to_log, err_msg: e.message, backtrace: e.backtrace })

    search_req.complete(EasySettings.finish_status.error)

    return { status: :error, response: e }
  end

  private

  def use_storage_data?(access_record, request_date)
    if access_record.accessed?
      if request_date.nil? ||
        access_record.last_fetch_date >= (Time.zone.today - request_date.days).to_time
        return true
      end
    end
    false
  end

  def close_db_connection
    ActiveRecord::Base.connection.close

  rescue ActiveRecord::ActiveRecordError => e
    unless e.message == 'Cannot expire connection, it is not currently leased.'
      raise ActiveRecord::ActiveRecordError, e.message
    end
  end

  def search_company_info(url, access_record, free_search_option, search_req)
    cf = Crawler::Corporate.new(url, supporting_urls: access_record.supporting_urls, option: free_search_option)
    cf.start
    cf
  rescue Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocWithUnrepeatableError => e
    :unobtainable_doc_with_unrepeatable

  rescue Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocError => e
    :unobtainable_doc_error

  # お知らせする
  rescue => e
    contents = "[#{Time.zone.now}] [requested_url: #{search_req.to_log}] [err_class: #{e.class}] [err_msg: #{e.message}] [backtrace: ] #{e.backtrace}"
    # NoticeMailer.deliver_later(NoticeMailer.notice_error(contents, 'クローラサーチエラー', 'error'))
    MyLog.new('crawl_alert').log "[#{Time.zone.now}] クローラサーチエラー #{contents}"
    :corporate_search_error
  end
end
