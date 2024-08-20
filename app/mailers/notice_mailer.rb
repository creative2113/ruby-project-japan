class NoticeMailer < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notice_mailer.send_mail.subject
  #

  def accept_requeste_mail(request)
    @title      = request.title
    @file_name  = request.file_name
    @accept_id  = request.accept_id
    @created_at = request.requested_date
    @url        = confirm_url(accept_id: @accept_id)
    @service    = EasySettings.service_name

    mail(
      to:      request.mail_address,
      subject: "#{pre_subject}リクエストを受け付けました。"
    )
  end

  def accept_requeste_mail_for_user(request)
    @title      = request.title
    @file_name  = request.file_name
    @created_at = request.requested_date
    @url        = confirm_url(accept_id: request.accept_id)
    @service    = EasySettings.service_name

    addresses   = [request.user.email]
    addresses.push(request.mail_address) if request.mail_address.present?

    mail(
      to:      addresses,
      subject: "#{pre_subject}リクエストを受け付けました。"
    )
  end

  def accept_simple_investigation(request)
    @title      = request.title
    @url        = request.corporate_list_site_start_url
    @service    = EasySettings.service_name

    mail(
      to:      request.user.email,
      subject: "#{pre_subject}簡易調査と簡易設定の申請が完了しました。"
    )
  end

  def received_simple_investigation(request)
    @request = request
    @title   = request.title
    @url     = request.corporate_list_site_start_url
    @user    = request.user
    @service = EasySettings.service_name

    mail(
      to:       "#{EasySettings.service_name} <#{Rails.application.credentials.mailer[:address]}>",
      from:     "#{EasySettings.service_name} <#{Rails.application.credentials.mailer[:address]}>",
      subject:  "#{pre_subject}簡易調査の依頼が届きました。【リクエストID: #{request.id}】【ユーザID: #{request.user_id}】"
    )
  end

  def request_complete_mail(request)
    @title      = request.title
    @file_name  = request.file_name
    @accept_id  = request.accept_id
    @created_at = request.requested_date
    @url        = confirm_url(accept_id: @accept_id)
    @service    = EasySettings.service_name

    mail(
      to:      request.mail_address,
      subject: "#{pre_subject}リクエストが完了しました。"
    )
  end

  def request_complete_mail_for_user(request)
    @title      = request.title
    @file_name  = request.file_name
    @created_at = request.requested_date
    @url        = confirm_url(accept_id: request.accept_id)
    @service    = EasySettings.service_name

    addresses   = [request.user.email]
    addresses.push(request.mail_address) if request.mail_address.present?

    mail(
      to:      addresses,
      subject: "#{pre_subject}リクエストが完了しました。"
    )
  end

  def notice_emergency_fatal(content, level = :fatal)
    @content   = content
    @level_str = EasySettings.error_level[level]
    @service   = EasySettings.service_name

    mail(
      to:      Rails.application.credentials.error_email_address,
      subject: "#{pre_subject}エラー発生　要#{@level_str}"
    )
  end

  def notice_error(content, title, level = :fatal)
    @content   = content
    @level_str = level.to_s
    @title     = title
    @service   = EasySettings.service_name

    mail(
      to:      Rails.application.credentials.error_email_address,
      subject: "#{pre_subject}#{@level_str}発生　#{@title}"
    )
  end

  def notice_simple(text, title = '', mark = '')
    @text    = text
    @title   = title
    @mark    = mark
    @service = EasySettings.service_name

    mail(
      to:      Rails.application.credentials.error_email_address,
      subject: "【#{Rails.env.upcase}】#{@mark}お知らせ： #{@title}"
    )
  end

  def notice_irregular(text, title = '', mark = '')
    @text    = text
    @title   = title
    @mark    = mark
    @service = EasySettings.service_name

    mail(
      to:      Rails.application.credentials.error_email_address,
      subject: "【#{Rails.env.upcase}】#{@mark}： #{@title}"
    )
  end

  def notice_attack(text, title = '', mark = '')
    @text    = text
    @title   = title
    @mark    = mark
    @service = EasySettings.service_name

    mail(
      to:      Rails.application.credentials.error_email_address,
      subject: "【#{Rails.env.upcase}】#{@mark}攻撃： #{@title}"
    )
  end

  def registered_user(user, ip = '')
    @email        = user.email
    @company_name = user.company_name
    @service      = EasySettings.service_name
    @ip           = ip

    mail(
      to:      Rails.application.credentials.error_email_address,
      subject: "#{pre_subject}ユーザが登録されました。"
    )
  end

  def notice_action(user, action, message = '')
    @email    = user.email
    @message  = message
    @user     = user
    @action   = action
    @service  = EasySettings.service_name

    mail(
      to:      Rails.application.credentials.error_email_address,
      subject: "#{pre_subject}#{action}が実行されました。(ID: #{user.id})"
    )
  end

  def accepted_inquiry(inquiry)
    @name       = inquiry.name
    @mail       = inquiry.mail
    @inquiry_id = inquiry.id
    @bodies     = inquiry.body.split("\n")
    @service    = EasySettings.service_name

    mail(
      to:      inquiry.mail,
      subject: "#{pre_subject}お問い合わせを受け付けました。【質問番号: #{@inquiry_id}】"
    )
  end

  def received_inquiry(inquiry)
    @name       = inquiry.name
    @mail       = inquiry.mail
    @inquiry_id = inquiry.id
    @bodies     = inquiry.body.split("\n")
    @service    = EasySettings.service_name

    mail(
      to:       "#{EasySettings.service_name} <#{Rails.application.credentials.mailer[:address]}>",
      from:     "#{EasySettings.service_name} <#{Rails.application.credentials.mailer[:address]}>",
      reply_to: @mail,
      subject:  "#{pre_subject}お問い合わせが届きました。【質問番号: #{@inquiry_id}】"
    )
  end

  def accept_plan_registration(user, plan_num)
    @user     = user
    @plan     = EasySettings.plan.invert[plan_num]
    @url      = inquiry_url
    @service  = EasySettings.service_name

    mail(
      to:      [user.email, Rails.application.credentials.error_email_address],
      subject: "#{pre_subject}有料プランへの登録が完了致しました。"
    )
  end

  def accept_plan_change(user, before_plan_num, after_plan_num, price_this_time, up_or_down)
    @user            = user
    @up_or_down      = up_or_down
    @before_plan     = EasySettings.plan.invert[before_plan_num]
    @after_plan      = EasySettings.plan.invert[after_plan_num]
    @price_this_time = price_this_time
    @url             = inquiry_url
    @service         = EasySettings.service_name

    mail(
      to:      [user.email, Rails.application.credentials.error_email_address],
      subject: "#{pre_subject}プランの変更が完了致しました。"
    )
  end

  def accept_plan_stop(user, plan_name)
    @user     = user
    @plan     = PlanConverter.convert_to_sym(plan_name)
    @url      = inquiry_url
    @service  = EasySettings.service_name

    mail(
      to:      [user.email, Rails.application.credentials.error_email_address],
      subject: "#{pre_subject}有料プランの定期更新を停止致しました。"
    )
  end

  def accept_update_card(user, card_info)
    @user      = user
    @card_info = card_info
    @url       = inquiry_url
    @service   = EasySettings.service_name

    mail(
      to:      user.email,
      subject: "#{pre_subject}クレジットカード情報を変更しました。"
    )
  end

  private

  def pre_subject
    env = ( Rails.env.production? || Rails.env.test? ) ? '' : "【#{Rails.env.upcase}】"
    # "【#{@service}】#{env}"
    "#{env}"
  end

  class << self
    def deliver_later(mailer_instance)
      if Sidekiqer.new.alive_process?('mailers')
        mailer_instance.deliver_later
      else
        deliver_now(mailer_instance)
      end
    end

    def deliver_now(mailer_instance)
      mailer_instance.deliver_now
    rescue => e
      mailer_instance.deliver_later
    end
  end
end
