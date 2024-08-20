# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :check_ban_ips, only: [:create]
  # before_action :check_valid_company_name, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  before_action :confirm_billing_status, only: [:edit]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  def create
    unless verify_recaptcha
      @user = User.new(params.require(:user).permit(permit_attributes))
      # flash.to_hash.values[0]に reCAPTCHAエラーが入る（環境によって変わる可能性あり）
      flash.now[:alert] = flash.to_hash.values[0]
      # NoticeMailer.deliver_later(NoticeMailer.notice_irregular("MAIL: #{params['user']['email']}\n会社名: #{params['user']['company_name']}\nIP: #{request.remote_ip} \n\nparams: #{params['user']}", 'ユーザ登録がありました。'))
      NoticeMailer.deliver_later(NoticeMailer.notice_attack("IP: #{request.remote_ip} \nparams: #{params}", '変な登録リクエストがありました。'))
      render :new and return
    end

    super

    unless @user.id.nil?
      @user.build_billing(plan: EasySettings.plan[:free],
                          status: Billing.statuses[:unpaid],
                          expiration_date: Time.zone.now.end_of_month)

      @user.build_preferences

      @user.language = Crawler::Country.languages[:japanese]

      if cookies.encrypted[:rfd].present? && ( ref = Referrer.find_by(code: cookies.encrypted[:rfd]) ).present?
        @user.referrer_id = ref.id
        @user.referral_reason = User.referral_reasons[:url]
      end

      unless @user.save
        # 要緊急対応　問題(大) -> すぐに対応
        logging('fatal', request, { issue: 'build_billing failure', content: @user.billing.errors })
        content = "SESSION_ID[#{session[:session_id]}] USER_ID[#{@user.id}] ERROR_POINT[Users::RegistrationsController:create: build_billing failure] ERROR_CONTENT[#{@user.billing.errors}]"
        NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content))
      end

      @user.confirm_count_period

      cookies.delete(:rfd)

      NoticeMailer.deliver_later(NoticeMailer.registered_user(@user, request&.remote_ip))
    end
  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  protected

  def permit_attributes
    [:company_name,
     :family_name,
     :given_name,
     :department,
     :position,
     :tel,
     :terms_of_service]
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: permit_attributes)
  end

  def check_ban_ips
    if ( con = BanCondition.find(ip: request.remote_ip, action: BanCondition.ban_actions['user_register']) ).present?
      sleep 0.4
      con.count_up
      NoticeMailer.deliver_later(NoticeMailer.notice_attack("IP: #{request.remote_ip} \nparams: #{params}", '変な登録リクエストがありました。'))
      flash[:notice] = '本人確認用のメールを送信しました。メール内のリンクからアカウント作成を承認してください。承認が完了するまではログインできません。しばらく経ってもメールが送られてこない場合は、お手数ですがお問合せください。'
      redirect_to new_user_session_path and return
    end
  end

  def check_valid_company_name
    kanji_rex = Crawler::Country::Japan::KANJI_REX
    hira_rex  = Crawler::Country::Japan::HIRAGANA_REX
    kata_rex  = Crawler::Country::Japan::KATAKANA_REX

    return if params['user']['company_name'].blank?
    return if params['user']['company_name'].match?(kanji_rex) || params['user']['company_name'].match?(hira_rex) || params['user']['company_name'].match?(kata_rex)

    sleep 0.4
    NoticeMailer.deliver_later(NoticeMailer.notice_irregular("MAIL: #{params['user']['email']}\n会社名: #{params['user']['company_name']}\nIP: #{request.remote_ip} \n\nparams: #{params['user']}", 'ユーザ登録がありました。'))
    NoticeMailer.deliver_later(NoticeMailer.notice_attack("IP: #{request.remote_ip} \nparams: #{params}", '変な登録リクエストがありました。'))
    flash[:notice] = '本人確認用のメールを送信しました。メール内のリンクからアカウント作成を承認してください。承認が完了するまではログインできません。しばらく経ってもメールが送られてこない場合は、お手数ですがお問合せください。'
    redirect_to new_user_session_path and return
  end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  def after_inactive_sign_up_path_for(resource)
    new_user_session_path
  end

  def after_update_path_for(resource)
   edit_user_registration_path
 end
end
