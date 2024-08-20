module WorkerCommonUtil

  def get_page_limit(plan)
    if @req.only_this_page?
      [1, 1]
    else
      [EasySettings.corporate_list_search_page_limit[plan], EasySettings.corporate_list_analysis_page_limit[plan]]
    end
  end

  def make_config
    conf = {}
    conf[:only_paging] = @req.only_paging?
    conf
  end

  def safety?
    return true if @corporate_list && @req.list_site_analysis_result.present?

    case SealedPage.check_safety(@url)
    when :unsafe_from_saved_sealed_page

      @requested_url.complete(EasySettings.finish_status.unsafe_and_sealed_page)
      ActiveRecord::Base.connection.close
      log('info', { issue: "Unsafe URL From Sealeded", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})

      return false
    when :unsafe_from_url_web_checker

      @requested_url.complete(EasySettings.finish_status.unsafe_page)
      ActiveRecord::Base.connection.close
      log('info', { issue: "Unsafe URL From Web Checker", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})

      return false
    end
    true
  end

  def exist_domain?
    if @domain == '503' || @domain == '403'
      @requested_url.complete(EasySettings.finish_status.unavailable_site)
    elsif @domain == '404'
      @requested_url.complete(EasySettings.finish_status.invalid_url)
    elsif @domain.present?
      return true
    else
      @requested_url.complete(EasySettings.finish_status.invalid_url)
    end

    ActiveRecord::Base.connection.close
    log('info', { issue: "Domain Not Exist", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})
    false
  end

  def banned_domain?
    return false unless Url.ban_domain?(domain: @domain)

    @requested_url.complete(EasySettings.finish_status.banned_domain)
    ActiveRecord::Base.connection.close
    log('info', { issue: "Banned Domain Final", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})
    true
  end

  def sealed_page?(sealed_page)
    unsafe           = sealed_page.sealed_because_of_unsafe?
    can_not_get_info = sealed_page.sealed_because_can_not_get?

    return false if @free_search && !unsafe
    return false if @corporate_list && !unsafe
    return false if !can_not_get_info && !unsafe

    @requested_url.complete(EasySettings.finish_status.access_sealed_page)
    ActiveRecord::Base.connection.close
    log('info', { issue: "Sealeded URL", process_time: Time.zone.now - @start_time, requested_url: @requested_url.to_log})

    true
  end

  def sidekiq_rebooting?
    File.exist?("#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:sidekiq_reboot]}")
  end

  def set_crawl_config(crawler)
    if @req.corporate_list_config.blank? && @req.corporate_individual_config.blank?
      @opt = select_crawl_options(@domain)

      crawler.set_list_page_config(list_page_config: Json2.parse(@opt.corporate_list_config, symbolize: false)) if @opt&.corporate_list_config.present?
      crawler.set_individual_page_config(individual_page_config: Json2.parse(@opt.corporate_individual_config, symbolize: false)) if @opt&.corporate_individual_config.present?
    else
      @opt = nil
      crawler.set_list_page_config(list_page_config: Json2.parse(@req.corporate_list_config, symbolize: false)) if @req.corporate_list_config.present?
      crawler.set_individual_page_config(individual_page_config: Json2.parse(@req.corporate_individual_config, symbolize: false)) if @req.corporate_individual_config.present?
    end
  end

  def select_crawl_options(domain)
    options = ListCrawlConfig.where(domain: domain)
    ActiveRecord::Base.connection.close
    opt = nil
    if options.size > 1
      options.each { |option| opt = option if option.domain_path.present? && @req.corporate_list_site_start_url.include?(option.domain_path) }
    else
      opt = options[0]
    end
    opt
  end
end
