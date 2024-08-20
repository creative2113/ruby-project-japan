class CouponsController < ApplicationController

  before_action :authenticate_user!

  def new_trial
    @code = params[:coupon_code]
    if referrer_trial_invalid_message(@code).present?
      redirect_to edit_user_registration_path and return
    end
  rescue => e
    logging('error', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    flash[:alert] = Message.const[:error_occurred_retry_latter]

    redirect_to edit_user_registration_path and return
  end

  def create_trial
    if referrer_trial_invalid_message(params[:coupon_code]).present?
      @finish_status = :invalid_request
      redirect_to edit_user_registration_path and return
    end

    ip = request.remote_ip

    plan_name = 'beta_standard'
    plan_num  = EasySettings.plan[plan_name]
    @plan     = PlanConverter.convert_to_plan(plan_num)

    raise "「#{plan_name}」が存在しません。" unless Billing.plan_list.include?(plan_name)

    token = params['payjp-token']

    billing = current_user.billing

    customer = nil
    begin
      ActiveRecord::Base.transaction do
        begin
          coupon = Coupon.find_referrer_trial
          UserCoupon.create!(user: current_user, coupon: coupon, count: 1)
        rescue => e
          # 要対応　問題(中) -> 2,3日中に対応
          logging('error', request, { finish: 'Save Failure: UserCoupon クーポン保存に失敗しました。', err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
          content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: UserCoupon クーポン保存に失敗しました。] PARAMS[#{params}] ERROR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
          NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
          flash[:alert] = Message.const[:error_occurred_retry_latter]
          @finish_status = :create_trial_coupon_error
          raise e
        end

        # プランレコードを作成
        begin
          billing.update!(payment_method: Billing.payment_methods[:credit])
          billing.create_plan!(@plan.id, charge_date: (Time.zone.now + 11.days).day, start_at: Time.zone.now, end_at: nil, trial: true)
        rescue => e
          # 要対応　問題(中) -> 2,3日中に対応
          logging('error', request, { finish: 'Save Failure: トライアル課金プラン保存に失敗しました。', err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
          content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: トライアル課金プラン保存に失敗しました。] PARAMS[#{params}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
          NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
          flash[:alert] = Message.const[:error_occurred_retry_latter]
          @finish_status = :create_trial_plan_error
          raise e
        end

        begin
          Billing.try_connection(0.5, 40) do
            customer = billing.create_customer(token)
          end
        rescue => e
          # 要対応　問題(中) -> 2,3日中に対応
          logging('error', request, { finish: 'PAYJP Make Customer Failure: PAYJPの顧客登録に失敗しました。', response: customer, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
          content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: PAYJP Make Customer Failure] RESPONSE[#{customer}] PARAMS[#{params}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
          NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
          flash[:alert] = Message.const[:card_registration_failure]
          @finish_status = :create_payjp_customer_error
          raise e
        end
      end
    rescue => e
      redirect_to edit_user_registration_path and return
    end

    begin
      billing.update!(customer_id: customer.id)
    rescue => e
      # 要対応　問題(大) -> できるだけすぐに対応
      logging('fatal', request, { finish: 'カスタマーIDの保存に失敗しました。できるだけ早く、カスタマーIDをuser.billing.customer_idに保存してください。', customer_id: customer.id, customer: customer, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      content = "SESSION_ID[#{session[:session_id]}] IP[#{ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}: カスタマーIDの保存に失敗しました。できるだけ早く、カスタマーIDをuser.billing.customer_idに保存してください。] CUSTOMER_ID[#{customer.id}] CUSTOMER[#{customer}] PARAMS[#{params}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :fatal))
      @finish_status = :save_customer_id_error
    end

    flash[:notice] = Message.const[:success_trial_coupon]
    redirect_to edit_user_registration_path and return
  rescue => e
    logging('error', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    @finish_status = :error_occurred
    flash[:alert] = Message.const[:error_occurred_retry_latter]

    redirect_to edit_user_registration_path and return
  end

  def add
    code = params[:coupon_code]

    if code.blank?
      flash[:alert] = Message.const[:coupon_code_is_blank]
      redirect_to edit_user_registration_path and return
    end

    if ( coupon = Coupon.find_by_code(code) ).present?

    elsif ( ref = Referrer.find_by(code: code) ).present?

      if ( msg = referrer_trial_invalid_message(code) ).present?
        flash[:alert] = msg
        redirect_to edit_user_registration_path and return
      end

      current_user.update!(referrer_id: ref.id, referral_reason: User.referral_reasons[:coupon])

      redirect_path = coupon_trial_path(coupon_code: code)

    else
      @coupon_code = code
      flash.now[:alert] = Message.const[:invalid_code]
      @coupon_error_message = Message.const[:invalid_code]
      render 'devise/registrations/edit', status: :bad_request and return
    end

    # flash[:notice] = Message.const[:register_coupon_code]
    redirect_to redirect_path and return
  rescue => e
    logging('error', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    flash[:alert] = Message.const[:error_occurred_retry_latter]

    redirect_to edit_user_registration_path and return
  end

  private

  def referrer_trial_invalid_message(code)

    if code.blank?
      return Message.const[:coupon_code_is_blank]
    end

    if current_user.referrer_trial_coupon.present?
      return Message.const[:used_coupon_code]
    end

    ref = Referrer.find_by(code: code)

    if ref.blank?
      return Message.const[:invalid_code]
    end

    if current_user.referrer.present? && current_user.referral_reason_coupon? && current_user.referrer.id != ref.id
      return Message.const[:invalid_coupon_code]
    end

    if current_user.trial? || current_user.paid? || current_user.created_at < Time.zone.now - 32.days
      return Message.const[:expired_coupon_code]
    end

    nil
  end
end
