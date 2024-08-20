class RequestsController < ApplicationController
  include Pagy::Backend

  before_action :confirm_billing_status, only: [:index, :index_multiple, :create, :recreate, :stop, :confirm, :download]

  MODE_MULTIPLE  = 'multiple'.freeze
  MODE_CORPORATE = 'corporate'.freeze

  # corporate (企業一覧サイトから収集)
  def index
    prepare_request_list(mode: MODE_CORPORATE)

    if params[:r].present?

      res = get_redis_value(key: "#{params[:r]}_request")

      return if res.blank?

      set_response(res: res)

    end
  rescue => e
    flash[:alert]  = "エラーが発生しました。"
    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace})
  end

  # 複数情報取得
  def index_multiple
    prepare_request_list(mode: MODE_MULTIPLE)

    @init = params[:init] || '0'

    if params[:r].present?

      res = get_redis_value(key: "#{params[:r]}_request")

      return if res.blank?

      set_response(res: res)

    end
  rescue => e
    flash[:alert]  = "エラーが発生しました。"
    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace})
  end

  def create
    decide_render_action

    prepare_request_list

    ip                   = request.remote_ip
    @use_storage         = params[:request][:use_storage] == '1' ? true : false
    @using_storaged_date = params[:request][:using_storage_days]
    @free_search         = params[:request][:free_search] == '1' ? true : false
    @mail_address        = params[:request][:mail_address]
    @type                = Request.types[params[:request_type]]
    @invalid_urls        = []
    @accepted            = false
    test                 = false

    file_info                     = {extension: nil, header: nil, sheet_num_or_name: nil, url_column_num: nil}
    file_info[:header]            = params[:header] == '1' ? true : false
    file_info[:sheet_num_or_name] = params[:sheet_select]
    file_info[:url_column_num]    = params[:col_select].to_i

    params[:request][:token] = params[:authenticity_token]
    params[:request][:type]  = @type

    if @type == Request.types[:file]

      #####  Clam AV を封印 START   ######
      #
      # Virus Check
      # begin
      #   response = ClamChowder::Scanner.new.scan_io(params[:request][:excel])
      # rescue => e
      #   if e.message.include?('Connection refused - connect(2)') && e.message.include?('port 3310')
      #     @finish_status = :virus_check_restarting
      #     @notice_create_msg = Message.const[:virus_check_restarting]
      #     render action: @render_action, status: 400 and return
      #   else
      #     raise e
      #   end
      # end

      # if response.infected?
      #   @virus_file_path = params[:request][:excel].path
      #   begin
      #     File.delete(@virus_file_path)
      #   rescue => e
      #     logging('fatal', request, { issue: "Virus File Uploaded, Failed Delete File: PATH:#{@virus_file_path}", err_msg: e.message, backtrace: e.backtrace })
      #   end

      #   if File.exist?(@virus_file_path)
      #     issue = "Must Delete Virus File: PATH:#{@virus_file_path}"
      #     logging('fatal', request, { issue: issue })
      #     content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] ISSUE[#{issue}]"
      #     NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content))
      #   else
      #     logging('warn', request, { issue: "Deleted Completely Virus File: PATH:#{@virus_file_path}" })
      #   end

      #   @finish_status = :virus_file_uploaded
      #   logging('warn', request, { finish: 'Virus File Uploaded' })
      #   @notice_create_msg = Message.const[:virus_file_uploaded]
      #   render action: @render_action, status: 400 and return
      # end
      #
      #
      #####  Clam AV を封印 END   ######

      @file_name = params[:request][:excel].original_filename
      params[:request][:title] = @file_name

    elsif @type == Request.types[:csv_string]

      @file_name = params[:file_name]
      params[:request][:title] = @file_name

      params[:request][:excel] = nil

    elsif @type == Request.types[:word_search]

      keyword    = params[:keyword_for_word_search]
      @file_name = keyword + '検索'
      params[:request][:title] = @file_name

      params[:request][:excel] = nil

    elsif @type == Request.types[:company_db_search]
      @init = 4
      @file_name = params[:list_name]
      @file_name = "DB検索" if @file_name&.strip.blank?
      params[:request][:title] = @file_name

      params[:request][:excel] = nil

      params[:request][:db_areas] = params[:areas]&.values.sort.to_json if params[:areas].present?
      params[:request][:db_categories] = params[:categories]&.values.sort.to_json if params[:categories].present?

      params[:request][:not_own_capitals] = ( current_user&.administrator? && params[:request][:not_own_capitals] == '1' )

      tmp_db_groups = {}
      tmp_db_groups[CompanyGroup::CAPITAL] = params[:capital]&.values.sort if params[:capital].present?
      tmp_db_groups[CompanyGroup::EMPLOYEE] = params[:employee]&.values.sort if params[:employee].present?
      tmp_db_groups[CompanyGroup::SALES] = params[:sales]&.values.sort if params[:sales].present?
      tmp_db_groups[CompanyGroup::NOT_OWN_CAPITALS] = params[:request][:not_own_capitals] if current_user&.administrator? && params[:request][:not_own_capitals]
      params[:request][:db_groups] = tmp_db_groups.to_json if tmp_db_groups.present?

    elsif @type == Request.types[:corporate_list_site]

      if params[:execution_type].blank? || !['test', 'main'].include?(params[:execution_type])
        exec_error_proc(:invalid_execution_type, 'info', { finish: 'Invalid Execution Type Request' }, Message.const[:unaccept_request])
        render action: @render_action, status: 400 and return
      end

      @corporate_list_site_start_url = params[:request][:corporate_list_site_start_url]

      params[:request][:title] = "#{Url.get_domain(@corporate_list_site_start_url)}の検索" if params[:request][:title].blank?
      params[:request][:excel] = nil
      params[:request][:test]  = params[:execution_type] == 'test'
      test                     = params[:request][:test]

    # Upload type check
    else
      @finish_status = :invalid_type
      logging('info', request, { finish: 'Invalid Type Request', type: @type })
      @notice_create_msg = Message.const[:unaccept_request]
      render action: @render_action, status: 400 and return
    end

    # Storage Date Condition check
    if @use_storage
      if !@using_storaged_date.empty? && @using_storaged_date.match(/[^\d]/)
        exec_error_proc(:using_strage_setting_invalid, 'info', { finish: 'Invalid Storage Data Request' }, Message.const[:confirm_storage_date])
        render action: @render_action, status: 400 and return
      end
      @using_storaged_date = @using_storaged_date == '' ? nil : @using_storaged_date.to_i
    end


    if @type == Request.types[:word_search]

      # キーワードの未入力チェック
      if keyword.blank?
        @finish_status = :keyword_blank
        logging('info', request, { finish: 'Keyword Is Blank', type: @type, keyword: keyword })
        @notice_create_msg = Message.const[:keyword_is_blank]
        render action: @render_action, status: 400 and return
      end
    elsif @type == Request.types[:company_db_search]
      area_connectors     = params[:areas].present? ? params[:areas]&.values : nil
      category_connectors = params[:categories].present? ? params[:categories]&.values : nil
      capital_groups      = params[:capital].present? ? params[:capital]&.values : nil
      employee_groups     = params[:employee].present? ? params[:employee]&.values : nil
      sales_groups        = params[:sales].present? ? params[:sales]&.values : nil
      not_own_capitals    = params[:request][:not_own_capitals]

      if ( !user_signed_in? || !current_user.available?(:other_conditions_on_db_search) ) &&
         ( capital_groups.present? || employee_groups.present? || sales_groups.present? )
        @finish_status = :other_conditions_unavailable
        logging('info', request, { finish: 'Other Conditions Unavailable', type: @type, area_connectors: area_connectors, category_connectors: category_connectors, capital_groups: capital_groups, employee_groups: employee_groups, sales_groups: sales_groups })
        @notice_create_msg = Message.const[:other_conditions_unavailable]
        render action: @render_action, status: 400 and return
      end

      # 地域、業種、その他のグループの未入力チェック
      if area_connectors.blank? && category_connectors.blank? && capital_groups.blank? && employee_groups.blank? && sales_groups.blank?
        @finish_status = :area_category_group_blank
        logging('info', request, { finish: 'DB Search Area And Category And Groups Are Blank.', type: @type, area_connectors: area_connectors, category_connectors: category_connectors, capital_groups: capital_groups, employee_groups: employee_groups, sales_groups: sales_groups })
        @notice_create_msg = Message.const[:area_category_groups_are_blank]
        render action: @render_action, status: 400 and return
      end
    elsif @type == Request.types[:corporate_list_site]
      # URLの未入力チェック
      if @corporate_list_site_start_url.blank?
        exec_error_proc(:corporate_list_site_start_url_blank, 'info', { finish: 'Corporate List Site URL Is Blank', type: @type, corporate_list_site_start_url: @corporate_list_site_start_url }, Message.const[:url_is_blank])
        render action: @render_action, status: 400 and return
      end

      # URLの形式チェック
      unless Url.correct_url_form?(@corporate_list_site_start_url)
        exec_error_proc(:invalid_url, 'info', { finish: 'Invalid Url' }, Message.const[:invalid_url])
        render action: @render_action, status: 400 and return
      end

      # ドメインのチェック
      domain = Url.get_domain(@corporate_list_site_start_url)
      if Url.ban_domain?(domain: domain)
        exec_error_proc(:ban_domain, 'info', { finish: 'Ban Domain' }, Message.const[:ban_domain])
        render action: @render_action, status: 400 and return
      end

      # 登録サイトの禁止URLの場合にエラーにする
      option_class = ListCrawlConfig.where(domain: domain)&.first&.class_name&.constantize
      if option_class.present? &&
         ( option_class&.ban_pathes || [] ).include?(@corporate_list_site_start_url.split('//')[1])
        message = option_class.ban_pathes_alert_message || Message.const[:unavailable_list_site_url]
        exec_error_proc(:unavailable_list_site_url, 'info', { finish: 'Unavailable List Site Url' }, message)
        render action: @render_action, status: 400 and return
      end

      # 企業一覧ページの入力チェック
      if invalid_corporate_list_config(params[:request][:corporate_list]).present?
        exec_error_proc(:invalid_corporate_list_params, 'info', { finish: 'Invalid Corporate List Params' }, Message.const[:invalid_parameters])
        render action: @render_action, status: 400 and return
      end

      # 企業個別ページの入力チェック
      if invalid_corporate_individual_config(params[:request][:corporate_individual]).present?
        exec_error_proc(:invalid_corporate_individual_params, 'info', { finish: 'Invalid Corporate Individual Params' }, Message.const[:invalid_parameters])
        render action: @render_action, status: 400 and return
      end

    else
      # アップロードファイル種別のチェック
      file_info[:extension] = File.extname(@file_name).downcase
      unless file_info[:extension] == '.xlsx' || file_info[:extension] == '.csv'
        @finish_status = :invalid_extension
        logging('info', request, { finish: 'Invalid Extension' })
        @notice_create_msg = Message.const[:invalid_extension]
        render action: @render_action, status: 400 and return
      end
    end

    # ユーザのアクセス制限
    if user_signed_in?
      @user = current_user

      if @user.monthly_acquisition_limit?
        exec_error_proc(:monthly_acquisition_limit, 'info', { finish: 'Over Monthly Acquisition Limit In request' }, Message.const[:over_monthly_acquisition_limit])
        render action: @render_action, status: 400 and return
      end

      if @user.requests.unfinished.size >= EasySettings.waiting_requests_limit[@user.my_plan]
        exec_error_proc(:waiting_requests_limit, 'info', { finish: 'Over Waiting Requests Limit' }, Message.const[:over_waiting_requests_limit])
        render action: @render_action, status: 400 and return
      end

      # 2022/5/8 一旦廃止、待機数制限に変更。必要ないと確信したら削除。
      # if @user.request_limit?
      #   @user.request_count_up

      #   @finish_status = :request_limit
      #   logging('info', request, { finish: 'Over Daily Access Limit In request' })
      #   @notice_create_msg = Message.const[:over_access]
      #   render action: @render_action, status: 400 and return
      # end

      if @user.monthly_request_limit?
        @user.request_count_up unless test
        exec_error_proc(:monthly_request_limit, 'info', { finish: 'Over Monthly Access Limit In request' }, Message.const[:over_monthly_limit])
        render action: @render_action, status: 400 and return
      end
      @user.request_count_up unless test
    else
      @user = User.get_public

      # パブリックユーザはメアド登録必須
      if @mail_address.blank?
        exec_error_proc(:public_ip_access_request_limit, 'info', { finish: 'Email Address Is Blank' }, Message.const[:email_address_blank])
        render action: @render_action, status: 400 and return
      end

      unless ValidatesEmailFormatOf.validate_email_format(@mail_address).nil?
        exec_error_proc(:public_ip_access_request_limit, 'info', { finish: 'Invalid Email Address' }, Message.const[:invalid_email_address])
        render action: @render_action, status: 400 and return
      end

      if @user.requests.unfinished_by_ip(ip).size >= EasySettings.public_access_limit.ip
        exec_error_proc(:public_ip_access_request_limit, 'info', { finish: 'Over Public IP Access Limit' }, Message.const[:over_public_ip_limit])
        render action: @render_action, status: 400 and return
      end

      if @user.requests.unfinished.size >= EasySettings.waiting_requests_limit.public
        exec_error_proc(:public_waiting_requests_limit, 'info', { finish: 'Over Public Waiting Requests Limit' }, Message.const[:over_public_waiting_limit])
        render action: @render_action, status: 400 and return
      end
    end

    # オリジナルクロール
    @free_search = false unless @user.available?(:free_search)

    if @free_search

      link_words   = Crawler::Country.find(Crawler::Country.japan[:english]).new
                                     .exclude_search_words(params[:request][:link_words].split_and_trim(',')[0..4].join(','))
      target_words = params[:request][:target_words].split_and_trim(',')[0..4]

      if link_words.blank? && target_words.blank?
        @free_search  = false
        params[:request][:link_words]   = nil
        params[:request][:target_words] = nil
      else
        @use_storage = false
        params[:request][:use_storage] = false

        params[:request][:link_words]   = link_words.join(',')
        params[:request][:target_words] = target_words.join(',')
        params[:request][:target_words] = target_words.join(',')

        @link_words   = params[:request][:link_words]
        @target_words = params[:request][:target_words]
      end
    else
      params[:request][:link_words]   = nil
      params[:request][:target_words] = nil
    end

    # トークンチェック
    # 同じユーザが同じファイル名をアクセスしてきたら、止める。
    # なんのため？
    # if Request.same_token?(@user.id, @file_name, params[:authenticity_token])
    #   @finish_status = :same_token
    #   logging('info', request, { finish: 'same_authenticity_token' })
    #   render action: @render_action, status: 400 and return
    # end


    # URLの抽出
    fetch_urls_from_google_search(keyword)
    fetch_urls_from_db(area_connectors, category_connectors, capital_groups, employee_groups, sales_groups, not_own_capitals)

    render action: @render_action, status: 400 and return unless success_import_and_extract_urls?(file_info)


    delete_upload_file

    # 正常URLの存在チェック
    render action: @render_action, status: 400 and return unless exist_valid_urls?

    # 受付IDの生成
    @accept_id = Request.create_accept_id


    params[:request][:user_id]     = user_signed_in? ? current_user.id : User.public_id
    params[:request][:free_search] = @free_search
    params[:request][:ip]          = ip
    params[:request][:plan]        = user_signed_in? ? current_user.my_plan_number : EasySettings.plan[:public]

    req = Request.new(request_params)

    req.file_name = @file_name
    req.status    = EasySettings.status.new
    req.accept_id = @accept_id

    req.corporate_list_config = arrange_corporate_list_params
    req.corporate_individual_config = arrange_corporate_individual_params
    req.save!

    prepare_request_list

    @accept_count = 0


    if @type == Request.types[:corporate_list_site]

      req_corp_list = SearchRequest::CorporateList.create_with_first_status(url: @corporate_list_site_start_url, request_id: req.id, test: req.test)

    else
      create_requested_urls(req.id)

      redirect_to action: @render_action, r: req.id and return unless exist_acceptable_url?(req)
    end

    req.save!

    if @type == Request.types[:corporate_list_site] && req.test
      response = BatchAccessor.new.request_test_search(req.id, req.user.id)

      if response.code.to_i != 200 && response.code.to_i != 500
        logging('error', request, { finish: 'Something Went Wrong on RequestsController', code: response.code, err_msg: response.body, backtrace: caller })
      end
    end

    @accepted = true

    begin
      if user_signed_in?
        NoticeMailer.deliver_later(NoticeMailer.accept_requeste_mail_for_user(req))
      else
        NoticeMailer.deliver_later(NoticeMailer.accept_requeste_mail(req)) if @mail_address.present?
      end
    rescue => e
      logging('fatal', request, { err_point: 'Notice Mailer', err_msg: e.message, backtrace: e.backtrace })
    end

    # 管理側への通知
    NoticeMailer.deliver_later(NoticeMailer.notice_action(@user, "#{req.type.to_s}検索", {req_id: req.id, email: req&.mail_address, url: req.corporate_list_site_start_url}.to_key_value))


    @finish_status = :normal_finish
    logging('info', request, { finish: 'Normal End' })

    set_to_redis(req)

    redirect_to action: @render_action, r: req.id
  rescue => e
    req.destroy unless req.nil?
    @accept_id = nil

    @finish_status = :error_occurred

    @notice_create_msg = Message.const[:unaccept_request]

    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })

    render action: @render_action, status: 500 and return
  end

  def recreate

    prepare_request_list

    ip = request.remote_ip

    @accepted = false

    req = Request.find_by_accept_id(params[:accept_id])

    if invalid_accept_id?(req)
      @notice_confirm = user_signed_in? ? Message.const[:no_exist_request] : Message.const[:invalid_accept_id]
      flash.now[:alert] = @notice_confirm
      render action: :index, status: 400 and return
    end

    if !req.corporate_list_site? || req.test == false || !req.finished?
      exec_error_proc(:unacceptable_reexecute, 'info', { finish: 'Unacceptable Re-execution' }, Message.const[:unacceptable_reexecute])
      render action: :index, status: 400 and return
    end

    @mail_address = req.mail_address
    @accept_id    = req.accept_id

    # ユーザのアクセス制限
    if user_signed_in?
      @user = current_user

      if @user.monthly_acquisition_limit?
        exec_error_proc(:monthly_acquisition_limit, 'info', { finish: 'Over Monthly Acquisition Limit In request' }, Message.const[:over_monthly_acquisition_limit])
        render action: @render_action, status: 400 and return
      end

      if @user.requests.unfinished.size >= EasySettings.waiting_requests_limit[@user.my_plan]
        exec_error_proc(:waiting_requests_limit, 'info', { finish: 'Over Waiting Requests Limit' }, Message.const[:over_waiting_requests_limit])
        render action: :index, status: 400 and return
      end

      # 2022/5/8 一旦廃止、待機数制限に変更。必要ないと確信したら削除。
      # if @user.request_limit?
      #   @user.request_count_up

      #   @finish_status = :request_limit
      #   logging('info', request, { finish: 'Over Daily Access Limit In request' })
      #   @notice_create_msg = Message.const[:over_access]
      #   render action: @render_action, status: 400 and return
      # end

      if @user.monthly_request_limit?
        @user.request_count_up

        exec_error_proc(:monthly_request_limit, 'info', { finish: 'Over Monthly Access Limit In request' }, Message.const[:over_monthly_limit])
        render action: :index, status: 400 and return
      end
      @user.request_count_up
    else
      @user = User.get_public

      if @user.requests.unfinished_by_ip(ip).size >= EasySettings.public_access_limit.ip
        exec_error_proc(:public_ip_access_request_limit, 'info', { finish: 'Over Public IP Access Limit' }, Message.const[:over_public_ip_limit])
        render action: :index, status: 400 and return
      end

      if @user.requests.unfinished.size >= EasySettings.waiting_requests_limit.public
        exec_error_proc(:public_waiting_requests_limit, 'info', { finish: 'Over Public Waiting Requests Limit' }, Message.const[:over_public_waiting_limit])
        render action: :index, status: 400 and return
      end
    end

    # トークンチェック
    # 同じユーザが同じファイル名をアクセスしてきたら、止める。
    # if Request.same_token?(@user.id, @file_name, params[:authenticity_token])
    #   @finish_status = :same_token
    #   logging('info', request, { finish: 'same_authenticity_token' })
    #   render action: @render_action, status: 400 and return
    # end


    ActiveRecord::Base.transaction do
      req.update!(status: EasySettings.status.new, test: false, ip: ip,
                  list_site_result_headers: nil,
                  accessed_urls: nil)

      req_corp_list = SearchRequest::CorporateList.create_with_first_status(url: req.corporate_list_site_start_url, request_id: req.id)
    end


    @accepted = true

    begin
      if user_signed_in?
        NoticeMailer.deliver_later(NoticeMailer.accept_requeste_mail_for_user(req))
      else
        NoticeMailer.deliver_later(NoticeMailer.accept_requeste_mail(req)) if @mail_address.present?
      end
    rescue => e
      logging('fatal', request, { err_point: 'Notice Mailer', err_msg: e.message, backtrace: e.backtrace })
    end

    # 管理側への通知
    NoticeMailer.deliver_later(NoticeMailer.notice_action(@user, "#{req.type.to_s}検索", {req_id: req.id, email: req&.mail_address, url: req.corporate_list_site_start_url}.to_key_value))


    @finish_status = :normal_finish
    logging('info', request, { finish: 'Normal End' })

    set_to_redis(req)

    redirect_to action: :index, r: req.id
  rescue => e

    @finish_status = :error_occurred

    @notice_create_msg = Message.const[:unaccept_request]

    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })

    render action: :index, status: 500 and return
  end

  def stop
    decide_render_action

    prepare_request_list

    ip         = request.remote_ip
    @accept_id = params[:accept_id]
    @result    = false


    req = Request.find_by_accept_id(@accept_id)

    if invalid_accept_id?(req)
      @notice_request_list_msg = user_signed_in? ? Message.const[:no_exist_request] : Message.const[:invalid_accept_id]
      render action: @render_action, status: 400 and return
    end

    decide_render_action_by_request(request: req)

    if req.status >= EasySettings.status.completed
      @finish_status = :can_not_stop
      logging('info', request, { finish: 'Can Not Stop' })
      @notice_request_list_msg = Message.const[:can_not_stop]
      render action: @render_action, status: 400 and return
    end

    req.stop

    @result = true
    flash[:notice] = Message.const[:stop_request]

    redirect_to action: @render_action
  rescue => e
    @finish_status = :error_occurred
    @notice_request_list_msg = Message.const[:error_occurred]
    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })
    render action: @render_action, status: 500 and return
  end

  def reconfigure

    prepare_request_list

    ip         = request.remote_ip
    @accept_id = params[:accept_id]
    @result    = false

    req = Request.find_by_accept_id(@accept_id)

    if invalid_accept_id?(req)
      @notice_confirm = user_signed_in? ? Message.const[:no_exist_request] : Message.const[:invalid_accept_id]
      flash.now[:alert] = @notice_confirm
      render action: :index, status: 400 and return
    end

    unless req.corporate_list_site?
      exec_error_proc(:not_corporate_list, 'info', { finish: 'Not Corporate List Site Request' }, Message.const[:invalid_accept_id])
      render action: :index, status: 400 and return
    end

    @title           = req.title
    @type            = req.type
    @test            = req.test
    @status          = req.get_status_string
    @fail_reason     = req.fail_reason
    @expiration_date = req.get_expiration_date
    @requested_date  = req.requested_date

    # 暫定処理。修正必須。
    @total_count     = req.requested_urls.main.size
    @waiting_count   = req.get_unfinished_urls.main.size
    @completed_count = req.get_completed_urls.main.size
    @error_count     = req.get_error_urls.main.size

    @download_files = req.available_result_files

    @corporate_list_site_start_url = req.corporate_list_site_start_url
    @list_config  = Json2.parse(req.corporate_list_config, symbolize: false)
    @indiv_config = Json2.parse(req.corporate_individual_config, symbolize: false)

    if req.test_req_url.present?
      @headers               = req.get_list_site_result_headers
      @corporate_list_result = req.test_req_url.select_test_data
      @separation_info       = req.test_req_url.separation_info
      delete_test_result_headers
    end

    @req = req

    @result = true

    set_request_contents_to_params(req, params)

    render action: :index
  end

  def confirm
    decide_render_action

    prepare_request_list

    ip         = request.remote_ip
    @accept_id = params[:accept_id]
    @result    = false

    req = Request.find_by_accept_id(@accept_id)

    if invalid_accept_id?(req)
      @notice_confirm = user_signed_in? ? Message.const[:no_exist_request] : Message.const[:invalid_accept_id]
      flash.now[:alert] = @notice_confirm
      render action: @render_action, status: 400 and return
    end

    decide_render_action_by_request(request: req)

    @title           = req.title
    @type            = req.type
    @test            = req.test
    @status          = req.get_status_string
    @fail_reason     = req.fail_reason
    @expiration_date = req.get_expiration_date
    @file_name       = req.file_name
    @requested_date  = req.requested_date

    # 暫定処理。修正必須。
    if req.corporate_list_site?
      @total_count     = req.requested_urls.main.size
      @waiting_count   = req.get_unfinished_urls.main.size
      @completed_count = req.get_completed_urls.main.size
      @error_count     = req.get_error_urls.main.size
    else
      @total_count     = req.accepted_url_count
      @waiting_count   = req.get_unfinished_urls.company_info_urls.size
      @completed_count = req.get_completed_urls.company_info_urls.size
      @error_count     = req.get_error_urls.company_info_urls.size

      @db_areas        = AreaConnector.areas_str(Json2.parse(req.db_areas))
      @db_categories   = CategoryConnector.categories_str(Json2.parse(req.db_categories))

      groups_data      = Json2.parse(req.db_groups, symbolize: false) || {}
      @db_capitals     = CompanyGroup.groups_str(CompanyGroup::CAPITAL, groups_data[CompanyGroup::CAPITAL])
      @db_employee     = CompanyGroup.groups_str(CompanyGroup::EMPLOYEE, groups_data[CompanyGroup::EMPLOYEE])
      @db_sales        = CompanyGroup.groups_str(CompanyGroup::SALES, groups_data[CompanyGroup::SALES])
      @not_own_capitals = true if current_user&.administrator? && groups_data[CompanyGroup::NOT_OWN_CAPITALS].present?
    end

    @download_files = req.available_result_files

    @corporate_list_site_start_url = req.corporate_list_site_start_url

    @list_config  = Json2.parse(req.corporate_list_config, symbolize: false)
    @indiv_config = Json2.parse(req.corporate_individual_config, symbolize: false)
    if req.test_req_url.present?
      @headers               = req.get_list_site_result_headers
      @corporate_list_result = req.test_req_url.select_test_data
      @separation_info       = req.test_req_url.separation_info
      delete_test_result_headers
    end

    @req = req

    @result = true

    render action: @render_action
  rescue => e
    @finish_status = :error_occurred
    @notice_confirm = Message.const[:error_occurred]
    flash.now[:alert] = @notice_confirm
    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })
    render action: @render_action, status: 500 and return
  end

  def download
    decide_render_action

    accept_id = params[:accept_id]

    req = Request.find_by_accept_id(accept_id)

    if invalid_accept_id?(req)
      flash[:alert] = user_signed_in? ? Message.const[:no_exist_request] : Message.const[:invalid_accept_id]
      # confirmでOK
      redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
    end

    unless req.available_download?
      logging('info', request, { finish: 'Expired Download Date' })
      flash[:alert] = Message.const[:expired_download]
      redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
    end

    file_path = if req.result_file_path.blank?
      result_file = ResultFile.create!(status: ResultFile.statuses[:accepted], request_id: req.id)
      result_file.make_file(:at_once)

      raise 'Make Excel Error' if result_file.path.blank?

      flash.now[:alert] = "#{Json2.parse(result_file.fail_files).join(', ').to_s}のファイル作成に失敗しました。" if result_file.fail_files.present?
      result_file.path
    else
      req.result_file_path
    end

    # 管理側への通知
    NoticeMailer.deliver_later(NoticeMailer.notice_action(req.user, "#{req.type.to_s} 結果ダウンロード", {req_id: req.id}.to_key_value)) unless current_user&.administrator?

    @finish_status = :normal_finish

    type = if file_path[-3..-1] == 'zip'
      'application/zip'
    else
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end

    data = S3Handler.new.download(s3_path: file_path).body

    send_data data.read, filename: file_path.split('/')[-1], disposition: 'attachment', type: type
  rescue => e
    @finish_status = :error
    logging('fatal', request, { finish: 'Download Failure', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    flash[:alert] = Message.const[:download_failure]
    redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
  end

  def make_result_file
    decide_render_action

    params = result_file_params
    accept_id = params[:accept_id]

    redirect_to action: :index and return unless user_signed_in?

    req = Request.find_by_accept_id(accept_id)

    if invalid_accept_id?(req)
      flash[:alert] = Message.const[:invalid_accept_id]
      # confirmでOK
      redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
    end

    if ResultFile.file_types[params[:file_type]].blank?
      logging('info', request, { finish: 'Invalid file_type' })
      @finish_status = :invalid_result_file_type
      flash[:alert] = Message.const[:invalid_result_file_type]
      redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
    end

    if req.over_expiration_date?
      logging('info', request, { finish: 'Expired Request Date' })
      @finish_status = :expired_download
      flash[:alert] = Message.const[:expired_download]
      redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
    end

    if req.result_files.unfinished.count >= 5
      logging('info', request, { finish: 'ResultFile Making Limit' })
      @finish_status = :result_file_making_limit
      flash[:alert] = Message.const[:result_file_making_limit]
      redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
    end

    result_file = ResultFile.create!(status: ResultFile.statuses[:accepted], request_id: req.id, file_type: ResultFile.file_types[params[:file_type]])

    response = BatchAccessor.new.request_result_file(result_file.id, req.user.id)

    if response.code.to_i == 200

      ResultFile.set_delete_flag!(req)

      @finish_status = :normal_finish

      flash[:notice] = Message.const[:accept_result_file]

      redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
    elsif response.code.to_i == 500
    else
      logging('error', request, { finish: 'Something Went Wrong on RequestsController', code: response.code, err_msg: response.body, backtrace: caller })
    end

    result_file.destroy!

    @finish_status = :error_occurred
    flash[:alert] = Message.const[:error_occurred_retry_latter]

    redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
  rescue => e
    @finish_status = :error
    logging('error', request, { finish: 'error', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    flash[:alert] = Message.const[:error_occurred_retry_latter]
    redirect_to confirm_path(accept_id: params[:accept_id], mode: @mode) and return
  end

  def get_result_file
    decide_render_action

    id = params[:id]

    redirect_to action: :index and return unless user_signed_in?

    result_file = ResultFile.find_by_id(id)

    if invalid_result_file_id?(result_file)
      flash[:alert] = Message.const[:error_occurred]
      redirect_to action: :index and return
    end

    accept_id = result_file.request.accept_id

    unless result_file.available_download?
      logging('info', request, { finish: 'Expired Download Date' })
      @finish_status = :expired_download
      flash[:alert] = Message.const[:expired_download]
      redirect_to confirm_path(accept_id: accept_id, mode: @mode) and return
    end

    file_path = result_file.path

    if file_path.blank?
      logging('info', request, { finish: 'File Path Blank' })
      @finish_status = :file_path_blank
      flash[:alert] = Message.const[:download_failure]
      redirect_to confirm_path(accept_id: accept_id, mode: @mode) and return
    end

    @finish_status = :normal_finish

    # 管理側への通知
    NoticeMailer.deliver_later(NoticeMailer.notice_action(result_file.request.user, "#{result_file.request.type.to_s} 結果ダウンロード", {req_id: result_file.request.id}.to_key_value))

    type = if file_path[-3..-1] == 'zip'
      'application/zip'
    else
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end

    data = S3Handler.new.download(s3_path: file_path).body

    send_data data.read, filename: file_path.split('/')[-1], disposition: 'attachment', type: type
  rescue => e
    @finish_status = :error
    logging('error', request, { finish: 'error', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    flash[:alert] = Message.const[:error_occurred_retry_latter]
    if accept_id.present?
      redirect_to confirm_path(accept_id: accept_id, mode: @mode) and return
    else
      redirect_to action: :index and return
    end
  end

  def request_simple_investigation

    accept_id = params[:accept_id]

    unless user_signed_in?
      render json: { error: '依頼に失敗しました。' }, status: :forbidden and return
    end

    req = Request.find_by_accept_id(accept_id)

    if invalid_accept_id?(req)
      render json: { error: '依頼に失敗しました。' }, status: :bad_request and return
    end

    unless req.corporate_list_site_start_url == params[:url]
      render json: { error: '依頼に失敗しました。' }, status: :bad_request and return
    end

    if SimpleInvestigationHistory.find_by_request_id(req.id).present?
      render json: { error: 'すでに簡易調査の申請を出しています。運営からの連絡をお待ちくださいませ。' }, status: :bad_request and return
    end

    if current_user.monthly_simple_investigation_limit?
      render json: { error: '利用制限に達しています。' }, status: :bad_request and return
    end

    ActiveRecord::Base.transaction do
      SimpleInvestigationHistory.create!(request: req, user: current_user, url: params[:url], domain: Url.get_domain(params[:url]))
      current_user.simple_investigation_count_up
    end

    begin
      NoticeMailer.deliver_later(NoticeMailer.accept_simple_investigation(req))
      NoticeMailer.deliver_later(NoticeMailer.received_simple_investigation(req))
    rescue => e
      logging('fatal', request, { err_point: 'Notice Mailer', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    end

    render json: { ok: 'accepted' }, status: :ok

  rescue => e
    @finish_status = :error
    logging('error', request, { finish: 'error', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    render json: { error: 'エラーが発生しました。時間をおいてから、再度実行ください。' }, status: :internal_server_error
  end

  private

  def get_redis_value(key:)
    redis = Redis.new

    res = redis.multi do |pipeline|
      pipeline.get(key)

      pipeline.del(key)
    end

    res[0]
  end

  def set_response(res:)
    res = Json2.parse(res)

    @title             = res[:title]
    @accepted          = res[:accepted]
    @finish_status     = res[:finish_status]
    @accept_id         = res[:accept_id]
    @type              = res[:type]
    @test              = res[:test]
    @file_name         = res[:file_name]
    @mail_address      = res[:mail_address]
    @free_search       = res[:free_search]
    @link_words        = res[:link_words]
    @target_words      = res[:target_words]
    @accept_count      = res[:accept_count]
    @invalid_urls      = res[:invalid_urls]
    @notice_create_msg = res[:notice_create_msg]
  end

  def set_to_redis(req)
    redis = Redis.new
    key   = "#{req.id}_request"

    res = redis.multi do |pipeline|
      pipeline.set key, { title:             req.title,
                          accepted:          @accepted,
                          finish_status:     @finish_status,
                          accept_id:         req.accept_id,
                          type:              req.type,
                          test:              req.test,
                          file_name:         req.file_name,
                          mail_address:      req.mail_address,
                          free_search:       req.free_search,
                          link_words:        req.link_words,
                          target_words:      req.target_words,
                          accept_count:      @accept_count,
                          invalid_urls:      @invalid_urls,
                          notice_create_msg: @notice_create_msg
                        }.to_json
      pipeline.expire(key, 10*60)
    end

    raise "Set Redis Error in #set_to_redis in request_controller: #{res}" unless res[0] == 'OK' && res[1] == true
    true
  end

  def invalid_accept_id?(req)
    if req.nil?
      @finish_status = :invalid_accept_id
      logging('info', request, { finish: 'Invalid Accept Id' })
      return true
    end

    unless req.available?
      @finish_status = :expired_request
      logging('info', request, { finish: 'Expired Request' })
      return true
    end

    user = user_signed_in? ? current_user : User.get_public

    if req.user != user && !user.administrator?
      @finish_status = :wrong_user
      logging('info', request, { finish: 'Wrong User' })
      return true
    end
    false
  end

  def invalid_result_file_id?(result_file)
    if result_file.nil?
      @finish_status = :invalid_result_file_id
      logging('info', request, { finish: 'Invalid ResultFile Id' })
      return true
    end

    user = user_signed_in? ? current_user : User.get_public

    if result_file.request.user != user && !user.administrator?
      @finish_status = :wrong_user
      logging('info', request, { finish: 'Wrong User' })
      return true
    end
    false
  end

  def create_requested_urls(request_id)
    inserter = BulkInserter.new(SearchRequest::CompanyInfo)

    @urls.each do |index, url|
      url = url.strip

      # URL check
      if url.empty?
        @invalid_urls.push({index: index, url: url, reason: 'URLが空'})
        next
      end

      unless Url.correct_url_form?(url)
        @invalid_urls.push({index: index, url: url, reason: 'URLの形式でない'})
        next
      end

      if Url.ban_domain?(url: url)
        @invalid_urls.push({index: index, url: url, reason: 'クロールが禁止されたドメイン'})
        next
      end

      # Don't do safety check and page existence check here

      inserter.add(SearchRequest::CompanyInfo.new_attributes_with_first_status(url, request_id))

      @accept_count += 1
    end

    inserter.execute!

  end

  def arrange_corporate_list_params

    return nil if params[:detail_off] == '1'

    tmp_params = params[:request][:corporate_list]

    return nil if tmp_params.nil? || tmp_params[:config_off] == '1'

    res = {}

    u_cnt = 0
    tmp_params.each do |u_idx, values|
      next if u_idx == 'config_off'
      next if values[:url].blank?
      u_cnt += 1

      res[u_cnt] = {url: values[:url]}
      ( res[u_cnt][:details_off] = '1'; next ) if values[:details_off] == '1'

      unless values[:organization_name].values.all_blank?
        cnt = 1
        org_name_res = {}
        values[:organization_name].each do |on_idx, org_name|
          next if org_name.blank?
          org_name_res[cnt] = org_name
          cnt += 1
        end
        res[u_cnt][:organization_name] = org_name_res
      end

      cnt = 1
      contents_res = {}
      values[:contents].each do |c_idx, contents|
        next if ([contents[:title]] + contents[:text].values).all_blank?

        contents_res[cnt] = { title: contents[:title], text: {} }

        t_cnt = 1
        contents[:text].each do |ct_idx, text|
          next if text.blank?
          contents_res[cnt][:text][t_cnt] = text
          t_cnt += 1
        end

        cnt += 1
      end

      res[u_cnt][:contents] = contents_res
    end

    res.blank? ? nil : res.to_json
  end

  def arrange_corporate_individual_params

    return nil if params[:detail_off] == '1'

    tmp_params = params[:request][:corporate_individual]

    return nil if tmp_params.nil? || tmp_params[:config_off] == '1'

    res = {}

    u_cnt = 0
    tmp_params.each do |u_idx, values|
      next if u_idx == 'config_off'
      next if values[:url].blank?
      u_cnt += 1

      res[u_cnt] = {url: values[:url]}
      ( res[u_cnt][:details_off] = '1'; next ) if values[:details_off] == '1'

      if values[:organization_name].present?
        res[u_cnt][:organization_name] = values[:organization_name]
      end

      cnt = 1
      contents_res = {}
      values[:contents].each do |c_idx, contents|
        next if contents[:title].blank? && contents[:text].blank?

        contents_res[cnt] = { title: contents[:title], text: contents[:text] }
        cnt += 1
      end

      res[u_cnt][:contents] = contents_res
    end

    res.blank? ? nil : res.to_json
  end

  def invalid_corporate_list_config(corporate_list_params)
    return nil if params[:detail_off] == '1'
    return nil if corporate_list_params.blank?

    corporate_list_params.each do |idx, each_params|
      next if idx == 'config_off'

      url = each_params[:url]
      return 'URLの形式で入力して下さい。' if url.present? && !Url.correct_url_form?(url)

      next if each_params[:details_off] == '1'

      return 'URLを入力してください。' if url.blank? && !each_params[:organization_name].values.all_blank?

      return '会社名は２つ以上入力してください。' if each_params[:organization_name].values.count_present_value == 1

      each_params[:contents].each do |idx2, values|
        return 'URLを入力してください。' if url.blank? && !([values[:title]] + values[:text].values).all_blank?

        if values[:title].blank? && values[:text].values.count_present_value == 1
          return '種別名は必ず入力してください。内容文字列は２つ以上入力してください。'
        elsif values[:text].values.count_present_value == 1
          return '内容文字列は２つ以上入力してください。'
        elsif values[:title].blank? && values[:text].values.count_present_value >= 2
          return '種別名は必ず入力してください。'
        elsif values[:title].present? && values[:text].values.count_present_value == 0
          return '内容文字列は２つ以上入力してください。'
        end
      end
    end
    nil
  end

  def invalid_corporate_individual_config(corporate_individual_params)
    return nil if params[:detail_off] == '1'
    return nil if corporate_individual_params.blank?

    corporate_individual_params.each do |idx, each_params|
      next if idx == 'config_off'

      url = each_params[:url]
      return 'URLの形式で入力して下さい。' if url.present? && !Url.correct_url_form?(url)

      next if each_params[:details_off] == '1'

      return 'URLを入力してください。' if url.blank? && !each_params[:organization_name].blank?

      each_params[:contents].each do |idx2, values|
        return 'URLを入力してください。' if url.blank? && ( values[:title].present? || values[:text].present? )

        if values[:title].blank? && values[:text].present?
          return '種別名は必ず入力してください。'
        elsif values[:title].present? && values[:text].blank?
          return '内容文字列は必ず入力してください。'
        end
      end
    end
    nil
  end

  def fetch_urls_from_google_search(keyword)
    return unless @type == Request.types[:word_search]

    # キーワード検索 Google検索でURL取得
    us    = Crawler::UrlSearcher.new(keyword)
    cnt   = (EasySettings.excel_row_limit[@user.my_plan] * 1.2).to_i
    @urls = us.fetch_compressed_urls_with_index(cnt)

    @urls.delete_if { |idx, url| idx > EasySettings.excel_row_limit[@user.my_plan].to_i }
  end

  def fetch_urls_from_db(area_connectors, category_connectors, capital_groups, employee_groups, sales_groups, not_own_capitals = false)
    return unless @type == Request.types[:company_db_search]

    domains = Company.select_domain_by_connectors(area_connectors, category_connectors, capital_groups, employee_groups, sales_groups, not_own_capitals, EasySettings.excel_row_limit[@user.my_plan].to_i)

    @urls = domains.map.with_index(1) { |d, i| [i, "https://#{d}"] }.to_h
  end

  # URLの抽出
  def success_import_and_extract_urls?(file_info)
    return true if @type == Request.types[:corporate_list_site] || @type == Request.types[:word_search] || @type == Request.types[:company_db_search]

    if file_info[:extension] == '.xlsx'
      uf = Excel::Import.new(params[:request][:excel].path, file_info[:sheet_num_or_name], file_info[:header])

    elsif file_info[:extension] == '.csv'
      if @type == Request.types[:csv_string]
        uf = CsvHandler.new(params[:csv_str], file_info[:header])
      else
        uf = CsvHandler::Import.new(params[:request][:excel].path, file_info[:header])
      end
    else
      raise "Invalid extension(#{file_info[:extension]}): extension should be csv or xlsx."
    end

    row_limit = EasySettings.excel_row_limit[@user.my_plan]
    @urls = uf.get_one_column_values_with_index(file_info[:url_column_num], row_limit)

    true
  rescue => e
    exec_error_proc(:excel_file_import_error, 'error', { finish: 'Excel File Import Error', err_msg: e.message, backtrace: e.backtrace },
                    Message.const[:excel_import_error])
    false
  end

  def delete_upload_file
    if params[:request][:excel].present?
      begin
        File.delete(params[:request][:excel].path)
      rescue => e
        logging('error', request, { issue: "Failed Delete Normal File: PATH:#{params[:request][:excel].path}", err_msg: e.message, backtrace: e.backtrace })
      end
    end
  end

  # 正常URLの存在チェック
  def exist_valid_urls?
    return true if @type == Request.types[:corporate_list_site]

    if @urls.values.reject(&:blank?).empty?
      exec_error_proc(:no_valid_url, 'info', { finish: 'No Valid Url' }, Message.const[:no_valid_url])
      return false
    end

    true
  end

  def exist_acceptable_url?(req)
    return true if @accept_count != 0

    req.status = EasySettings.status.completed
    req.save!

    exec_error_proc(:no_acceptable_url, 'info', { finish: 'No Acceptable Url' })
    @accept_id     = nil
    flash[:alert]  = Message.const[:no_valid_url]
    set_to_redis(req)

    false
  end

  def exec_error_proc(finish_stats, log_level = 'info', log_option = {}, message = nil)
    # finish_statusはテストの確認のためだけに使用している
    @finish_status = finish_stats
    logging(log_level, request, log_option)
    @notice_create_msg = message if message.present?
    flash.now[:alert] = message if message.present?
  end

  def request_params
    params.require(:request)
          .permit(:title, :excel, :mail_address, :use_storage, :using_storage_days, :db_areas, :db_categories, :db_groups, :user_id, :type,
                  :token, :free_search, :link_words, :target_words, :ip, :test, :plan, :corporate_list_site_start_url, :paging_mode)
  end

  def set_request_contents_to_params(req, params)
    params[:request] = {}
    params[:requested_url] = {}
    params[:request][:mail_address] = req.mail_address
    params[:request][:use_storage] = req.use_storage ? '1' : '0'
    params[:request][:using_storage_days] = req.using_storage_days
    params[:request][:paging_mode] = req.paging_mode

    params[:request][:free_search] = req.free_search

    params[:request][:title] = req.title
    params[:request][:corporate_list_site_start_url] = req.corporate_list_site_start_url

    corporate_list_config = Json2.parse(req.corporate_list_config, symbolize: false)
    corporate_individual_config = Json2.parse(req.corporate_individual_config, symbolize: false)

    params[:detail_off] = corporate_list_config.present? || corporate_individual_config.present? ? '0' : '1'

    params[:request][:corporate_list] = make_corporate_list_config_to_params(corporate_list_config)

    params[:request][:corporate_individual] = make_corporate_individual_config_to_params(corporate_individual_config)

    params
  end

  def make_corporate_list_config_to_params(corporate_list_config)

    conf_res = {}

    conf_res[:config_off] = corporate_list_config.present? ? '0' : '1'

    return conf_res if corporate_list_config.blank?

    corporate_list_config.each do |idx, hash|
      conf_res[idx] = {}
      conf_res[idx][:url] = hash['url']

      conf_res[idx][:details_off] = hash['organization_name'].present? || hash['contents'].present? ? '0' : '1'

      if hash['organization_name'].present?
        conf_res[idx][:organization_name] = {}
        hash['organization_name'].each do |org_num, org_name|
          conf_res[idx][:organization_name][org_num] = org_name
        end
      end

      if hash['contents'].present?
        conf_res[idx][:contents] = {}
        hash['contents'].each do |con_num, content|
          conf_res[idx][:contents][con_num] = {}
          conf_res[idx][:contents][con_num][:text] = {}
          conf_res[idx][:contents][con_num][:title] = content['title']
          conf_res[idx][:contents][con_num][:text]['1'] = content['text']['1']
          conf_res[idx][:contents][con_num][:text]['2'] = content['text']['2']
          conf_res[idx][:contents][con_num][:text]['3'] = content['text']['3']
        end
      end
    end

    conf_res
  end

  def make_corporate_individual_config_to_params(corporate_individual_config)

    conf_res = {}

    conf_res[:config_off] = corporate_individual_config.present? ? '0' : '1'

    return conf_res if corporate_individual_config.blank?

    corporate_individual_config.each do |idx, hash|
      conf_res[idx] = {}
      conf_res[idx][:url] = hash['url']

      conf_res[idx][:details_off] = hash['organization_name'].present? || hash['contents'].present? ? '0' : '1'

      if hash['organization_name'].present?
        conf_res[idx][:organization_name] = hash['organization_name']
      end

      if hash['contents'].present?
        conf_res[idx][:contents] = {}
        hash['contents'].each do |con_num, content|
          conf_res[idx][:contents][con_num] = {}
          conf_res[idx][:contents][con_num][:title] = content['title']
          conf_res[idx][:contents][con_num][:text]  = content['text']
        end
      end
    end

    conf_res
  end

  def delete_test_result_headers
    return if @headers.blank? || @corporate_list_result.blank?
    headers = @corporate_list_result.values.map { |d| d.keys }.flatten.uniq
    @headers.delete_if { |hd| !headers.include?(hd) }
  end

  def prepare_request_list(mode: nil)
    return unless user_signed_in?

    requests = if mode.present?
      mode == MODE_MULTIPLE ? current_user.requests.not_corporate_list_site : current_user.requests.corporate_list_site
    else
      params[:mode] == MODE_MULTIPLE ? current_user.requests.not_corporate_list_site : current_user.requests.corporate_list_site
    end
    @pagy, @requests = pagy(requests.viewable.order(created_at: :desc, id: :desc))
  end

  def decide_render_action
    @render_action = params[:mode] == MODE_MULTIPLE ? 'index_multiple' : 'index'
    @mode          = params[:mode] == MODE_MULTIPLE ? MODE_MULTIPLE : MODE_CORPORATE
  end

  def decide_render_action_by_request(request:)
    before_mode = @mode
    @render_action = request.corporate_list_site? ? 'index' : 'index_multiple'
    @mode          = request.corporate_list_site? ? MODE_CORPORATE : MODE_MULTIPLE
    prepare_request_list(mode: @mode) unless before_mode == @mode
  end

  def confirm_billing_status
    current_user.confirm_billing_status if user_signed_in?
  end

  def result_file_params
    params.permit(:file_type, :accept_id)
  end
end
