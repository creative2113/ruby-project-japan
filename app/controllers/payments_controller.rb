class PaymentsController < ApplicationController
  include Pagy::Backend

  before_action :check_admin, only: [:index, :modify, :create_bank_transfer, :continue_bank_transfer, :create_invoice]
  before_action :confirm_billing_status, only: [:edit, :create, :update, :stop, :update_card]
  before_action :authenticate_user!

  def index

    redirect_back fallback_location: root_path and return unless permitted_user?(:administrator)

    if params[:user_id_or_email].present?
      if params[:user_id_or_email] == params[:user_id_or_email].to_i.to_s
        begin
          @user = User.find(params[:user_id_or_email].to_i)
        rescue => e
          @user = nil
          flash[:alert] = 'ユーザが存在しません。'
        end
      else
        @user = User.find_by_email(params[:user_id_or_email])

        if @user.nil?
          flash[:alert]  = "ユーザ(#{params[:user_id_or_email]})が存在しません。"
        end
      end

      # Admin画面ができるまでの仮対応
      if @user.present?
        @list_site_pagy, @list_site_requests = pagy(@user.requests.corporate_list_site.order(created_at: :desc, id: :desc), page_param: :page_list_site)
        @multi_pagy,     @multi_requests     = pagy(@user.requests.not_corporate_list_site.order(created_at: :desc, id: :desc), page_param: :page_multi)
        @search_pagy,    @search_requests    = pagy(@user.search_requests.order(created_at: :desc, id: :desc), page_param: :page_search)

        @req        = @user.requests.find_by_id(params[:request_id]) if params[:request_id].present?
        @req_urls   = @req.requested_urls if @req.present?
        @search_req = @user.search_requests.find_by_id(params[:search_request_id]) if params[:search_request_id].present?
        @req_url    = RequestedUrl.find_by_id(params[:request_url_id]) if params[:request_url_id].present?

        if @req.present?
          @test = @req.test
          @status = @req.get_status_string
          if @req.test_req_url.present?
            @headers               = @req.get_list_site_result_headers
            @corporate_list_result = @req.test_req_url.select_test_data
            @separation_info       = @req.test_req_url.separation_info
            delete_test_result_headers
          end
        end
      end
    end

  rescue => e
    flash[:alert]  = "エラーが発生しました。"
    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace})
  end

  def modify

    redirect_back fallback_location: root_path and return unless permitted_user?(:administrator)

    if wrong_check_string?(params[:check])
      flash[:alert]  = "チェック文字がおかしいです。"
      @finish_status = :wrong_check_character
      redirect_back fallback_location: root_path and return
    end

    new_plan_num = params[:new_plan].to_i

    if wrong_plan?(new_plan_num) || params['commit'] != '変更'
      @finish_status = :wrong_plan
      redirect_back fallback_location: root_path and return
    end

    begin
      @user = User.find(params[:user_id].to_i)
    rescue => e
      flash[:alert]  = "ユーザ(#{params[:user_id]})が存在しません。"
      @finish_status = :user_does_not_exist
      redirect_back fallback_location: root_path and return
    end

    if @user.administrator? || @user.id == User.public_id
      flash[:alert]  = "このユーザは変更できません。"
      @finish_status = :can_not_change
      redirect_back fallback_location: root_path and return
    end

    billing = @user.billing

    add_message = ''

    if params[:to_do] == 'create'
      customer = billing.search_customer
      if customer.nil?
        res = false
        add_message = 'PAYJPでユーザが見つかりません。　'
      else
        subscription_res = customer.subscriptions.data[0]
        res = billing.create_new_subscription(new_plan_num, subscription_res)
      end
    elsif params[:to_do] == 'upgrade'
      res = billing.upgrade_plan(new_plan_num)
    elsif params[:to_do] == 'downgrade'
      res = billing.set_next_plan(new_plan_num)
    elsif params[:to_do] == 'downgrade_now'
      if @user.billing.next_plan.nil?
        add_message = '次のプランが未定なので、即時ダウングレードできません。'
      else
        res = billing.downgrade_plan
      end
    elsif params[:to_do] == 'stop'
      res = billing.stop_billing
    end

    if res
      flash[:notice] = '変更に成功しました'
    else
      flash[:alert]  = "変更に失敗しました。エラー理由: #{add_message}#{billing.errors}"
    end

    @finish_status = :normal_finish
    redirect_to action: 'index', user_id_or_email: @user.id

  rescue => e
    flash[:alert]  = "エラーが発生しました。"
    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })
  end

  def create_bank_transfer

    redirect_back fallback_location: root_path and return unless permitted_user?(:administrator)

    if wrong_check_string?(params[:str_check])
      flash[:alert]  = "チェック文字がおかしいです。"
      @finish_status = :wrong_check_character
      redirect_back fallback_location: root_path and return
    end

    if wrong_plan?(params[:new_plan].to_i)
      @finish_status = :wrong_plan
      redirect_back fallback_location: root_path and return
    end

    @user = User.find_by_email(params[:email])

    if @user.nil?
      flash[:alert]  = "ユーザ(#{params[:email]})が存在しません。"
      @finish_status = :user_does_not_exist
      redirect_back fallback_location: root_path and return
    end

    if @user.administrator? || @user.id == User.public_id
      flash[:alert]  = "このユーザは変更できません。"
      @finish_status = :can_not_change
      redirect_back fallback_location: root_path and return
    end

    begin
      date = Time.zone.parse(params[:expiration_date]).end_of_day
    rescue => e
      flash[:alert]  = "有効期限がおかしいです。"
      @finish_status = :strange_expiration_date
      redirect_back fallback_location: root_path and return
    end

    if ( params[:payment_amount].present? && params[:payment_date].blank? ) ||
       ( params[:payment_amount].blank? && params[:payment_date].present? )
      flash[:alert]  = "入金日と入金金額は両方入力してください。もしくは、両方空欄にしてください。"
      redirect_back fallback_location: root_path and return
    end

    if params[:payment_date].present?
      begin
        payment_date = Time.zone.parse(params[:payment_date]).end_of_day
      rescue => e
        flash[:alert]  = "入金日がおかしいです。"
        redirect_back fallback_location: root_path and return
      end
    end

    if params[:payment_amount].present?
      unless params[:payment_amount].to_i.to_s == params[:payment_amount]
        flash[:alert]  = "入金金額は数値を入力してください。"
        redirect_back fallback_location: root_path and return
      end
    end

    ActiveRecord::Base.transaction do
      @user.billing.set_bank_transfer_plan(@plan.id, date)

      if params[:payment_amount].present? && params[:payment_date].present?
        item_name = params[:additional_comment].present? ? "#{@plan.name} #{params[:additional_comment]}" : @plan.name
        BillingHistory.create!(item_name: item_name, payment_method: @user.billing.payment_method, price: params[:payment_amount], billing_date: payment_date.to_date, unit_price: params[:payment_amount], number: 1, billing: @user.billing)
      end
    end

    flash[:notice] = "銀行振込ユーザを作成しました。"

    redirect_to action: 'index', user_id_or_email: @user.id

  rescue => e
    flash[:alert]  = "エラーが発生しました。#{e.class} #{e.message} : #{e.backtrace[0..5]}"
    logging('fatal', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
    redirect_back fallback_location: root_path and return
  end

  def continue_bank_transfer

    redirect_back fallback_location: root_path and return unless permitted_user?(:administrator)

    if wrong_check_string?(params[:str_check])
      flash[:alert]  = "チェック文字がおかしいです。"
      @finish_status = :wrong_check_character
      redirect_back fallback_location: root_path and return
    end

    @user = User.find_by_email(params[:email])

    if @user.nil?
      flash[:alert]  = "ユーザ(#{params[:email]})が存在しません。"
      @finish_status = :user_does_not_exist
      redirect_back fallback_location: root_path and return
    end

    if @user.administrator? || @user.id == User.public_id
      flash[:alert]  = "このユーザは変更できません。"
      @finish_status = :can_not_change
      redirect_back fallback_location: root_path and return
    end

    unless @user.billing.bank_transfer?
      flash[:alert]  = "このユーザは銀行振込ユーザではありません。"
      redirect_back fallback_location: root_path and return
    end

    plan = @user.billing.current_plans[0]
    if plan.blank? || !plan.ongoing?
      flash[:alert]  = "このユーザの銀行振込プランの有効期限は切れているか、ステータスが有効ではありません。"
      redirect_back fallback_location: root_path and return
    end

    begin
      date = Time.zone.parse(params[:expiration_date]).end_of_day
    rescue => e
      flash[:alert]  = "有効期限がおかしいです。"
      @finish_status = :strange_expiration_date
      redirect_back fallback_location: root_path and return
    end

    if date <= plan.end_at
      flash[:alert]  = "新しい有効期限が現在の有効期限より過去になっています。"
      redirect_back fallback_location: root_path and return
    end

    if ( params[:payment_amount].present? && params[:payment_date].blank? ) ||
       ( params[:payment_amount].blank? && params[:payment_date].present? )
      flash[:alert]  = "入金日と入金金額は両方入力してください。もしくは、両方空欄にしてください。"
      redirect_back fallback_location: root_path and return
    end

    if params[:payment_date].present?
      begin
        payment_date = Time.zone.parse(params[:payment_date]).end_of_day
      rescue => e
        flash[:alert]  = "入金日がおかしいです。"
        redirect_back fallback_location: root_path and return
      end
    end

    if params[:payment_amount].present?
      unless params[:payment_amount].to_i.to_s == params[:payment_amount]
        flash[:alert]  = "入金金額は数値を入力してください。"
        redirect_back fallback_location: root_path and return
      end
    end

    ActiveRecord::Base.transaction do
      plan.update!(end_at: date)

      if params[:payment_amount].present? && params[:payment_date].present?
        item_name = params[:additional_comment].present? ? "#{plan.name} #{params[:additional_comment]}" : plan.name
        BillingHistory.create!(item_name: item_name, payment_method: :bank_transfer, price: params[:payment_amount], billing_date: payment_date.to_date, unit_price: params[:payment_amount], number: 1, billing: @user.billing)
      end
    end

    flash[:notice] = "銀行振込を継続しました。"

    redirect_to action: 'index', user_id_or_email: @user.id

  rescue => e
    flash[:alert]  = "エラーが発生しました。#{e.class} #{e.message} : #{e.backtrace[0..5]}"
    logging('fatal', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
    redirect_back fallback_location: root_path and return
  end

  def create_invoice

    redirect_back fallback_location: root_path and return unless permitted_user?(:administrator)

    if wrong_plan?(params[:new_plan_for_invoice].to_i)
      @finish_status = :wrong_plan
      redirect_back fallback_location: root_path and return
    end

    @user = User.find_by_email(params[:email_for_invoice])

    if @user.nil?
      flash[:alert]  = "ユーザ(#{params[:email_for_invoice]})が存在しません。"
      @finish_status = :user_does_not_exist
      redirect_back fallback_location: root_path and return
    end

    if @user.administrator? || @user.id == User.public_id
      flash[:alert]  = 'このユーザは変更できません。'
      @finish_status = :can_not_change
      redirect_back fallback_location: root_path and return
    end

    begin
      date = Time.zone.parse(params[:start_date_for_invoice]).beginning_of_day
    rescue => e
      flash[:alert]  = '開始日がおかしいです。'
      @finish_status = :strange_start_date
      redirect_back fallback_location: root_path and return
    end

    # [検討] billing_hisotryは作らなてくいいのか？
    ActiveRecord::Base.transaction do
      @user.billing.set_invoice_plan(@plan.id, date)
    end

    flash[:notice] = '請求書払いユーザを作成しました。'

    redirect_to action: 'index', user_id_or_email: @user.id

  rescue => e
    flash[:alert] = "エラーが発生しました。#{e.class} #{e.message} : #{e.backtrace[0..5]}"
    logging('fatal', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
    redirect_back fallback_location: root_path and return
  end

  def edit
    ip = request.remote_ip

    redirect_back fallback_location: root_path and return unless permitted_user?(:subscription_plan_user)

    get_card_info
  end

  # クレジットカード払いで定期課金を作成する
  def create_credit_subscription
    ip = request.remote_ip

    plan_num = params['plan'].to_i

    redirect_back fallback_location: root_path and return unless permitted_user?(:login)

    redirect_back fallback_location: root_path and return if wrong_plan?(plan_num)

    unless Devise::Encryptor.compare(current_user.class, current_user.encrypted_password, params[:password_for_plan_registration])
      logging('info', request, { finish: 'Wrong Password' })
      flash[:alert] = Message.const[:wrong_password]
      @finish_status = :wrong_password
      redirect_back fallback_location: root_path and return
    end

    token = params['payjp-token']

    billing = current_user.billing

    customer = nil
    begin
      Billing.try_connection(0.5, 40) do
        customer = billing.create_customer(token)
      end
    rescue => e
      # 要対応　問題(中) -> 2,3日中に対応
      logging('error', request, { finish: 'PAYJP Make Customer Failure', response: customer, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: PAYJP Make Customer Failure] RESPONSE[#{customer}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
      flash[:alert] = Message.const[:charge_failure]
      @finish_status = :create_customer_error
      redirect_back fallback_location: root_path and return
    end

    begin
      ActiveRecord::Base.transaction do
        # プランレコードを作成
        begin
          billing.update!(customer_id: customer.id,
                          payment_method: Billing.payment_methods[:credit])
          billing.create_plan!(@plan.id)
        rescue => e
          # 要対応　問題(中) -> 2,3日中に対応
          # カスタマー削除が必要
          logging('error', request, { finish: 'PAYJP Make Subscription Failure: Should Delete Customer、数日中にPAY.JPのカスタマーを削除してください。', customer: customer, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
          content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: PAYJP Make Subscription Failure: Should Delete Customer、数日中にPAY.JPのカスタマーを削除してください。] CUSTOMER[#{customer}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
          flash[:alert] = Message.const[:charge_failure]
          NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
          @finish_status = :create_plan_error
          raise e
        end

        # 課金する
        res = nil
        begin
          plan   = billing.current_plans[0]
          amount = plan.charge_and_status_update_by_credit

          Billing.try_connection(0.5, 40) do
            res = plan.billing.create_charge(amount)
          end

          BillingHistory.create!(item_name: plan.name, payment_method: billing.payment_method, price: amount, billing_date: Time.zone.today, unit_price: amount, number: 1, billing: billing)
        rescue => e
          # 要対応　問題(中) -> 2,3日中に対応
          # カスタマー削除が必要
          logging('error', request, { finish: 'PAYJP Make Subscription Failure: Should Delete Customer By Few days、数日中にPAY.JPのカスタマーを削除してください。', customer: customer, response: res, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
          content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: PAYJP Make Subscription Failure: Should Delete Customer、数日中にPAY.JPのカスタマーを削除してください。] CUSTOMER[#{customer}] RESPONSE[#{res}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
          flash[:alert] = Message.const[:charge_failure]
          NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
          @finish_status = :create_charge_error
          raise e
        end
      end
    rescue => e
      redirect_back fallback_location: root_path and return
    end

    NoticeMailer.accept_plan_registration(current_user, plan_num).deliver_later

    @finish_status = :normal_finish
    flash[:notice] = Message.const[:payment_done]
    redirect_back fallback_location: root_path
  rescue => e
    @finish_status = :error_occurred

    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace})

    redirect_back fallback_location: root_path and return
  end

  # プラン変更は連絡してもらい、後で止める
  def update
    ip = request.remote_ip

    redirect_back fallback_location: root_path and return unless permitted_user?(:subscription_plan_user)

    get_card_info

    billing = current_user.billing

    new_plan_id = params['plan'].to_i

    # 正しいプランかチェック
    render action: 'edit', status: 400 and return if wrong_plan?(new_plan_id)

    unless Devise::Encryptor.compare(current_user.class, current_user.encrypted_password, params[:password_for_plan_change])
      logging('info', request, { finish: 'Wrong Password' })
      flash.now[:alert] = Message.const[:wrong_password]
      @finish_status = :wrong_password
      render action: 'edit', status: 400 and return
    end

    new_master_plan = MasterBillingPlan.find(new_plan_id)
    new_plan_name   = new_master_plan.name
    my_plan_name    = current_user.my_plan
    before_plan     = billing.current_plan

    ### プランアップグレード ###
    #
    # 前プランを終了し、新しいプランを作成する
    # 新プランで早速課金する
    #
    #########################
    if before_plan.price < new_master_plan.price

      # 定期課金のプランの変更


        ActiveRecord::Base.transaction do

          billing.change_plan!(new_plan_id)

          # 課金する
          begin
            res = billing.charge_by_plan

            raise 'Error Response Return' if res['error']
          rescue => e
            # 要対応　問題(中) -> 2,3日中に対応
            logging('error', request, { issue: 'PAYJP Create Charge Failure', Price: "¥#{@price_this_time.nil? ? 0 : @price_this_time}", new_plan: new_plan_num, response: res, err_msg: e.message, backtrace: e.backtrace })
            content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: PAYJP Create Charge Failure: Price: ¥#{@price_this_time.nil? ? 0 : @price_this_time}: New plan: #{new_plan_num}] RESPONSE[#{res}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
            NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
            raise e
          end
        rescue => e
          redirect_back fallback_location: root_path and return
        end



      unless billing.upgrade_plan(new_plan_num)
        # 要緊急対応　問題(大) -> すぐに対応
        logging('fatal', request, { issue: 'Upgrade Save Failure', Price: "¥#{@price_this_time.nil? ? 0 : @price_this_time}", new_plan: new_plan_num, error_content: current_user.billing.errors, err_msg: 'billing.upgrade_plan failed', backtrace: []})
        content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: Upgrade Save Failure: Price: ¥#{@price_this_time.nil? ? 0 : @price_this_time}: New plan: #{new_plan_num}]"
        NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content))
      end

      NoticeMailer.accept_plan_change(current_user, before_plan_num, new_plan_num, @price_this_time, :up).deliver_later

    ### プランダウングレード ###
    #
    # 定期課金のプランを変更し、次の課金日までトライアルの設定をする
    #
    #########################
    elsif billing.plan > new_plan_num

      # トライアルユーザはダウングレード禁止
      if current_user.trial?
        logging('info', request, { finish: 'Downgrade For Trial' })
        flash.now[:alert] = Message.const[:bad_request]
        @finish_status = :downgrade_for_trial
        render action: 'edit', status: 400 and return
      end

      # 定期課金のプランの変更
      begin
        res = billing.change_subscription(EasySettings.payjp_plan_id[new_plan_name])

        raise 'Error Response Return' if res['error']
      rescue => e
        # 要対応　問題(中)
        logging('error', request, { finish: 'PAYJP Change Downgrade Subscription Failure', new_plan: new_plan_num, response: res, err_msg: e.message, backtrace: e.backtrace })
        content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: PAYJP Change Downgrade Subscription Failure: New plan: #{new_plan_num}] RESPONSE[#{res}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
        NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
        flash[:alert] = Message.const[:change_failure] + Message.const[:retry_later]
        @finish_status = :downgrade_change_subscription_failure
        render action: 'edit', status: 500 and return
      end

      unless billing.set_next_plan(new_plan_num)
        # 要対応　問題(小) -> 次回課金までに対応
        logging('error', request, { issue: 'Downgrade Save Failure', new_plan: new_plan_num, error_content: current_user.billing.errors, err_msg: 'billing.set_next_plan failed', backtrace: []})
        content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: Downgrade Save Failure: New plan: #{new_plan_num}] ERROR_CONTENT[#{current_user.billing.errors}]"
        NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
      end

      NoticeMailer.accept_plan_change(current_user, before_plan_num, new_plan_num, 0, :down).deliver_later

    # 同じプランの場合
    else
      @finish_status = :same_plan
      logging('warn', request, { finish: 'Same Plan', new_plan: new_plan_num })
      flash[:alert] = Message.const[:bad_request]
      render action: 'edit', status: 400 and return
    end

    @finish_status = :normal_finish

    flash[:notice] = Message.const[:plan_change_done]
    render action: 'edit'

  rescue => e
    @finish_status = :error_occurred

    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })

    render action: 'edit', status: 500 and return
  end

  # プランアップデートに関連する
  # def get_payment_info
  #   render json: { status: 400, reason: 'unlogin_user' } and return if unlogin_user?

  #   render json: { status: 400, reason: 'not subscription_plan_user' } and return unless subscription_plan_user?

  #   new_plan_num = params['plan'].to_i

  #   render json: { status: 400, reason: 'wrong_plan' } and return if wrong_plan?(new_plan_num)

  #   new_plan_name = EasySettings.plan.invert[new_plan_num]
  #   my_plan_name  = current_user.my_plan
  #   new_price     = EasySettings.amount[new_plan_name]

  #   billing = current_user.billing

  #   diff_days = difference_of_date(billing.expiration_date, Time.zone.now)

  #   # プランアップグレード
  #   if billing.plan < new_plan_num
  #     base_price = current_user.trial? ? 0 : EasySettings.amount[my_plan_name]
  #     diff_price = new_price - base_price

  #     price = diff_days == 0 ? 0 : ( diff_price / 31 ) * diff_days.floor

  #     json = { price: price, new_price: new_price, diff_price: diff_price, reset_days: diff_days}

  #   # プランダウングレード
  #   elsif billing.plan > new_plan_num

  #     json = { price: 0, new_price: new_price, diff_price: 0, reset_days: diff_days}
  #   else

  #     json = { status: 400, reason: 'not_change' }
  #   end

  #   render json: json

  # rescue => e
  #   logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })
  #   render json: { status: 500, reason: 'error_occurred' } and return
  # end

  # クレジット課金の停止
  def stop_credit_subscription
    ip = request.remote_ip

    redirect_back fallback_location: root_path and return unless permitted_user?(:subscription_plan_user)

    get_card_info

    billing = current_user.billing

    plan = billing.current_plans[0]

    unless Devise::Encryptor.compare(current_user.class, current_user.encrypted_password, params[:password_for_plan_stop])
      logging('info', request, { finish: 'Wrong Password' })
      flash.now[:alert] = Message.const[:wrong_password]
      @finish_status = :wrong_password
      render action: 'edit', status: 400 and return
    end

    if plan.next_charge_date == Time.zone.today
      flash.now[:alert] = '課金の更新日が過ぎているため、今の時間は停止できません。申し訳ありませんが、課金の更新処理が完了するまでお待ちください。更新処理は1日以内に完了する予定です。'
      @finish_status = :unstoppable
      render action: 'edit', status: 400 and return
    end

    res = nil
    begin
      # 20秒以内に終わらせる
      Billing.try_connection(0.5, 40) do
        res = billing.delete_customer
      end
    rescue => e
      # 要対応　問題(大) -> 即時に調査と対応
      logging('fatal', request, { finish: 'PAYJP Delete Customer Failure', response: res, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
      content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: PAYJP Delete Customer Failure 即時に調査と対応をしてください。] RESPONSE[#{res}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :fatal))
      flash[:alert] = Message.const[:fail_delete_subscription]
      @finish_status = :delete_customer_failure
      render action: 'edit', status: 500 and return
    end

    begin
      ActiveRecord::Base.transaction do
        plan.stop_at_next_update_date!
        MonthlyHistory.find_around(current_user).update!(end_at: plan.reload.end_at)
        billing.update!(customer_id: nil)
      end
    rescue => e
      # 要対応　問題(中) -> 2,3日の間に調査と対応
      logging('fatal', request, { issue: 'Billing Save Failure', error_content: current_user.billing.errors, err_class: e.class, err_msg: 'billing.stop_billing failed', backtrace: [] })
      content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: Billing Save Failure 2,3日の間に調査と対応をしてください。] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
    end

    NoticeMailer.accept_plan_stop(current_user, plan.name).deliver_later

    @finish_status = :normal_finish

    flash[:notice] = Message.const[:subscription_stop_done]
    redirect_to action: 'edit', controller: 'users/registrations' and return

  rescue => e
    @finish_status = :error_occured

    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })

    render action: 'edit', status: 500 and return
  end

  def update_card
    ip = request.remote_ip

    redirect_back fallback_location: root_path and return unless permitted_user?(:subscription_plan_user)

    begin
      card = get_card_info
      raise 'Error Response Return' if card['error']
    rescue => e
      # 要対応　問題(中)
      logging('error', request, { finish: 'Get Card Info Failure', response: card, err_msg: e.message, backtrace: e.backtrace })
      content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: Get Card Info Failure] RESPONSE[#{card}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
      flash.now[:alert] = Message.const[:card_update_failure] + Message.const[:retry_later]
      @finish_status = :get_card_info_failure
      render action: 'edit', status: 500 and return
    end

    unless Devise::Encryptor.compare(current_user.class, current_user.encrypted_password, params[:password_for_card_change])
      logging('info', request, { finish: 'Wrong Password' })
      flash.now[:alert] = Message.const[:wrong_password]
      @finish_status = :wrong_password
      render action: 'edit', status: 400 and return
    end

    billing = current_user.billing

    # begin
    #   card = billing.get_card_info
    #   raise 'Error Response Return' if card['error']
    # rescue => e
    #   # 要対応　問題(中)
    #   logging('error', request, { finish: 'Get Card Info Failure', response: card, err_msg: e.message, backtrace: e.backtrace })
    #   content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: Get Card Info Failure] RESPONSE[#{card}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
    #   NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
    #   flash.now[:alert] = Message.const[:card_update_failure] + Message.const[:retry_later]
    #   @finish_status = :get_card_info_failure
    #   render action: 'edit', status: 500 and return
    # end

    begin
      res = billing.create_card(params['payjp-token'])
      raise 'Error Response Return' if res['error']
    rescue => e
      # 要対応　問題(中)
      logging('error', request, { finish: 'Create Card Failure', response: res, err_msg: e.message, backtrace: e.backtrace })
      content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: Create Card Failure] RESPONSE[#{res}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
      flash.now[:alert] = Message.const[:card_update_failure] + Message.const[:retry_later]
      @finish_status = :create_card_failure
      render action: 'edit', status: 500 and return
    end

    begin
      res = billing.delete_card(card.id)
      raise 'Error Response Return' if res['error']
    rescue => e
      # 要対応　問題(中) -> 2,3日中に対応
      logging('error', request, { finish: 'Delete Card Failure', response: res, err_msg: e.message, backtrace: e.backtrace })
      content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: Delete Card Failure] RESPONSE[#{res}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
    end

    get_card_info

    NoticeMailer.accept_update_card(current_user, @card).deliver_later

    @finish_status = :normal_finish

    flash.now[:notice] = Message.const[:card_update_success]

    render action: 'edit'

  rescue => e

    @finish_status = :error_occured

    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })

    render action: 'edit', status: 500 and return
  end

  private

  def wrong_check_string?(str)
    str.nil? || str[0] != str[1] || str.size != 2
  end

  def difference_of_date(date_time1, date_time2)
    date1 = Date.parse(date_time1.strftime("%Y/%m/%d"))
    date2 = Date.parse(date_time2.strftime("%Y/%m/%d/"))
    (date1 - date2).to_i
  end

  def get_card_info
    res   = current_user.billing.get_card_info
    @card = {brand: res['brand'], last4: res['last4']}
    res
  end

  def unlogin_user?
    unless user_signed_in?
      @finish_status = :unlogin_user
      logging('warn', request, { finish: 'Unlogin User' })
      flash[:alert] = Message.const[:unlogin_user]
      true
    else
      false
    end
  end

  def subscription_plan_user?
    if ( plan = current_user.billing.current_plans[0] ).present?
      true
    else
      @finish_status = :not_trial
      logging('warn', request, { finish: 'Not Trial User' })
      flash[:alert] = Message.const[:bad_request]
      false
    end
  end

  def wrong_plan?(plan_num)
    if ( @plan = PlanConverter.convert_to_plan(plan_num) ).blank?
      logging('warn', request, { finish: "Wrong Plan Num:#{plan_num}" })
      flash[:alert] = Message.const[:wrong_plan]
      @finish_status = :wrong_plan
      true
    else
      false
    end
  end

  def permitted_user?(check_type)
    if unlogin_user?
      @finish_status = :unlogin_user
      return false
    end

    case check_type
    when :administrator
      unless current_user.administrator?
        @finish_status = :not_administrator
        return false
      end
    when :subscription_plan_user
      unless subscription_plan_user?
        @finish_status = :not_trial_nor_paid_user
        return false
      end
    when :login
    end

    true
  end

  def delete_test_result_headers
    return if @headers.blank? || @corporate_list_result.blank?
    headers = @corporate_list_result.values.map { |d| d.keys }.flatten.uniq
    @headers.delete_if { |hd| !headers.include?(hd) }
  end
end
