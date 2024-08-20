class SearchersController < ApplicationController

  before_action :confirm_billing_status, only: [:index, :search_request]

  def index
    @result_flg = false

    if params[:id].present?

      sq = SearchRequest.find_by_accept_id(params[:id])

      return if sq.blank? || !sq.complete? || sq.error?

      @user = current_user || User.get_public

      access_record = AccessRecord.new(sq.domain)
      if access_record.exist? && access_record.have_result?

        @result_flg = true
        @url        = sq.url

        if  sq.free_search && sq.free_search_result.present?
          opt_res =  JSON.parse(sq.free_search_result)
        else
          opt_res = {}
        end

        cd = access_record.company_data(opt_res)

        set_display_data(cd)

        flash[:notice] = Message.const[:get_info]

      else
        flash[:notice] = Message.const[:can_not_get_info]
      end

      sq.delete
    end

  rescue => e
    @result_flg    = false
    flash[:notice] = Message.const[:can_not_get_info]
    logging('error', request, { finish: 'Can not display company data', err_msg: e.message, backtrace: e.backtrace })
  end

  def search_request
    satrt_time             = Time.zone.now
    ip                     = request.remote_ip
    @url                   = params[:url].strip
    @use_storage           = params[:use_storage] == '1' ? true : false
    @using_storaged_date   = params[:using_storaged_date]
    @free_search           = params[:free_search] == '1' ? true : false
    @option                = {}
    @finish_status         = nil

    # Storage Date Condition check
    if @use_storage
      if !@using_storaged_date.empty? && @using_storaged_date.match(/[^\d]/)

        # finish_statusはテストの確認のためだけに使用している
        @finish_status = :using_strage_setting_invalid
        logging('info', request, { finish: 'Invalid Storage Data Request' })
        render json: { status: 400, message: Message.const[:confirm_storage_date] } and return
      end
      @using_storaged_date = @using_storaged_date == '' ? nil : @using_storaged_date.to_i
    end

    if user_signed_in?

      @user = current_user

      # 2022/5/8 一旦廃止。必要ないと確信したら削除。
      # if @user.over_access?
      #   @user.count_up
      #   @url = ''
      #   @finish_status = :user_over_access
      #   logging('info', request, { finish: 'Over Daily Access Limit' })
      #   render json: { status: 400, message: Message.const[:over_access] } and return
      # end

      if @user.over_monthly_limit?
        @user.count_up
        @url = ''
        @finish_status = :over_monthly_limit
        logging('info', request, { finish: 'Over Monthly Access Limit' })
        render json: { status: 400, message: Message.const[:over_monthly_limit] } and return
      end
      @user.count_up
    else
      @user = User.get_public
    end

    # 管理側への通知
    NoticeMailer.deliver_later(NoticeMailer.notice_action(@user, '単体検索', @url))

    # いわゆる待機リクエスト制限
    if @user.over_current_activate_limit?
      @finish_status = :current_access_limit
      if user_signed_in?
        logging('info', request, { finish: 'Over Current Access Limit' })
        notice_msg = Message.const[:over_current_access]
      else
        logging('error', request, { finish: 'Access Concentration', err_msg: 'パブリックユーザの待機リクエスト制限発生', backtrace: [] })
        notice_msg = Message.const[:access_concentration]
      end

      render json: { status: 400, message: notice_msg } and return
    end

    @free_search = false unless @user.available?(:free_search)

    if @free_search
      @option[:link_words]   = params[:free_search_link_words].split_and_trim(',').join(',')
      @option[:target_words] = params[:free_search_target_words]

      link_words   = Crawler::Country.find(Crawler::Country.japan[:english]).new.exclude_search_words(@option[:link_words])
      target_words = @option[:target_words].split_and_trim(',')[0..4]

      if link_words.blank? && target_words.blank?
        @free_search = false
        @option      = {}
      else
        @use_storage = false
      end
    end

    accept_id = SecureRandom.create_accept_id
    while SearchRequest.have_same_accept_id?(accept_id)
      accept_id = SecureRandom.create_accept_id
    end

    @sq = SearchRequest.new(url: @url,
                            accept_id: accept_id,
                            status: EasySettings.status[:new],
                            finish_status: nil,
                            use_storage: @use_storage,
                            using_storage_days: @using_storaged_date,
                            free_search: @free_search,
                            link_words: @option[:link_words],
                            target_words: @option[:target_words],
                            user: @user)

    # URL form check
    unless Url.correct_url_form?(@url)
      @finish_status = :invalid_url_form
      logging('info', request, { finish: 'Invalid Url Form' })
      render json: { status: 400, message: Message.const[:confirm_url] } and return
    end

    if Url.ban_domain?(url: @url)
      @finish_status = :ban_domain
      logging('info', request, { finish: 'Banned Domain' })
      render json: { status: 400, message: Message.const[:ban_domain] } and return
    end

    # 一次ドメイン判定
    # unless @free_search
    #   domain        = Url.get_domain(@url)
    #   access_record = AccessRecord.new(domain)

    #   if access_record.exist? && access_record.have_result?

    #     if ( @use_storage && use_storage_data?(access_record, @using_storaged_date) ) ||
    #        ( access_record.last_fetch_date > Time.zone.now - 5.hours )
    #       access_record.count_up

    #       @sq.save!
    #       @sq.complete(EasySettings.finish_status[:using_storaged_date], domain)

    #       @finish_status = :using_storaged_date
    #       render json: { status: 200, complete: true, accept_id: @sq.accept_id } and return
    #     end
    #   end
    # end

    # Safetey check
    case SealedPage.check_safety(@url)
    when :unsafe_from_saved_sealed_page

      @finish_status = :sealed_unsafe_url
      logging('info', request, { finish: 'Sealed Unsafe Url' })
      render json: { status: 400, message: Message.const[:unsafe_url] } and return

    when :unsafe_from_url_web_checker

      @finish_status = :checked_unsafe_url
      logging('info', request, { finish: 'Checked Unsafe Url' })
      render json: { status: 400, message: Message.const[:unsafe_url] } and return
    end

    domain = Url.get_final_domain(@url) # アクセス可能なURL以外は全てnil

    # URL check
    if domain.nil?
      @finish_status = :invalid_url
      logging('info', request, { finish: 'Invalid Url Request' })
      render json: { status: 400, message: Message.const[:confirm_url] } and return
    end

    if Url.ban_domain?(domain: domain)
      @finish_status = :ban_domain_final
      logging('info', request, { finish: 'Banned Domain Final' })
      render json: { status: 400, message: Message.const[:ban_domain] } and return
    end

    sp = SealedPage.new(domain)

    if sp.sealed_because_of_unsafe? ||
       ( !@free_search && sp.sealed_because_can_not_get? )
      @finish_status = :access_sealed_page
      logging('info', request, { finish: 'Access Sealed Page' })
      render json: { status: 400, message: Message.const[:can_not_get_info] } and return
    end

    access_record = AccessRecord.new(domain)
    if access_record.exist? && access_record.have_result?
      access_record.count_up

      if ( @use_storage && use_storage_data?(access_record, @using_storaged_date) )   ||
         ( access_record.last_fetch_date > Time.zone.now - 5.hours && !@free_search )

        @sq.save!
        @sq.complete(EasySettings.finish_status[:using_storaged_date], domain)

        @finish_status = :using_storaged_date
        render json: { status: 200, complete: true, accept_id: @sq.accept_id } and return
      end
    end

    if File.exist?("#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:sidekiq_reboot]}")
      @finish_status = :rebooting
      render json: { status: 400, message: Message.const[:rebooting] } and return
    end

    @sq.domain = domain
    @sq.save!

    response = BatchAccessor.new.request_search(@sq.id, @user.id)

    if response.code.to_i == 200
      @finish_status = :normal_finish

      render json: { status: 200, complete: false, accept_id: @sq.accept_id } and return
    elsif response.code.to_i == 500
    else
      logging('error', request, { finish: 'Something Went Wrong on SearchersController', code: response.code, err_msg: response.body, backtrace: caller })
    end

    @finish_status = :error_occurred
    render json: { status: 500, message: Message.const[:error_occurred_retry_latter] } and return

  rescue => e
    @finish_status = :error_occurred

    logging('fatal', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    @sq.delete if @sq.id.present?

    render json: { status: 500, message: Message.const[:error_occurred_retry_latter] } and return
  end

  def confirm_search
    message = ''

    sq = SearchRequest.find_by_accept_id(params[:accept_id])
    if sq.complete?

      case sq.finish_status
      when EasySettings.finish_status[:successful]
      when EasySettings.finish_status[:can_not_get_info]
        message = Message.const[:can_not_get_info]
      when EasySettings.finish_status[:using_storaged_date]
      when EasySettings.finish_status[:invalid_url]
        message = Message.const[:confirm_url]
      when EasySettings.finish_status[:access_sealed_page]
        message = Message.const[:can_not_get_info]
      when EasySettings.finish_status[:access_sealed_page]
        message = Message.const[:can_not_get_info]
      when EasySettings.finish_status[:unsafe_and_sealed_page]
        message = Message.const[:unsafe_url]
      when EasySettings.finish_status[:unsafe_page]
        message = Message.const[:unsafe_url]
      when EasySettings.finish_status[:error]
        message = Message.const[:can_not_get_info]
      else
        message = Message.const[:can_not_get_info]
      end
    end

    render json: { status: 200, complete: sq.complete?, success: sq.success?, message: message }
  end

  def fetch_candidate_urls
    word = params[:word]
    if word.empty? ||
       ( word.downcase == 'h' ) ||
       ( word.downcase == 'ht' ) ||
       ( word.downcase == 'htt' ) ||
       ( word[0..3].downcase == 'http' )
      render json: { status: 200, urls: '' } and return
    end

    res = Crawler::UrlSearcher.new(word).fetch_results(10)

    res.each_with_index do |r, i|
      if r[:url].empty?
        res.delete_at(i)
        next
      end

      res[i][:title] = r[:title].encode("UTF-8", :invalid => :replace, :undef => :replace)
      res[i][:url] = 'http://' + r[:url] unless r[:url][0..3] == 'http'
    end

    render json: { status: 200, urls: res }

  rescue => e

    logging('error', request, { err_msg: e.message, backtrace: e.backtrace })

    render json: { status: 500, urls: '', message: Message.const[:get_url_error_occured] }
  
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

  def set_display_data(company_data_instance)
    @result     = company_data_instance.localize_clean_data
    @json       = company_data_instance.json
    @domain     = company_data_instance.domain
    @result_flg = true
  end
end
