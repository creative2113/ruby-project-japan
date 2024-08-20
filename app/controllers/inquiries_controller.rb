class InquiriesController < ApplicationController
  def new
    @inquiry = Inquiry.new
  end

  def create
    unless verify_recaptcha
      @inquiry = Inquiry.new(inquiry_params)
      # flash.to_hash.values[0]に reCAPTCHAエラーが入る（環境によって変わる可能性あり）
      flash.now[:alert] = flash.to_hash.values[0]
      NoticeMailer.deliver_later(NoticeMailer.notice_attack("IP: #{request.remote_ip} \nparams: #{params}", '変なお問合せがありました。'))
      render :new, status: 400 and return
    end

    params[:inquiry][:name] = params[:inquiry][:name].hyper_strip
    params[:inquiry][:mail] = params[:inquiry][:mail].hyper_strip
    params[:inquiry][:body] = params[:inquiry][:body].hyper_strip

    if params[:inquiry][:name].empty? || params[:inquiry][:mail].empty? || params[:inquiry][:body].empty?
      @notice_msg    = Message.const[:need_mandatory_fields]
      @finish_status = :need_mandatory_fields
      @inquiry       = Inquiry.new(inquiry_params)
      render action: 'new', status: 400 and return
    end

    if params[:inquiry][:name].size > 30
      @notice_msg    = Message.const[:invalid_name]
      @finish_status = :invalid_name
      @inquiry       = Inquiry.new(inquiry_params)
      render action: 'new', status: 400 and return
    end

    unless ValidatesEmailFormatOf.validate_email_format(params[:inquiry][:mail]).nil?
      @notice_msg    = Message.const[:invalid_email_address]
      @finish_status = :invalid_email_address
      @inquiry       = Inquiry.new(inquiry_params)
      render action: 'new', status: 400 and return
    end

    params[:inquiry][:user_id] = user_signed_in? ? current_user.id : User.public_id

    if BanCondition.ban?(mail: params[:inquiry][:mail].hyper_strip, action: BanCondition.ban_actions['inquiry'])
      NoticeMailer.deliver_later(NoticeMailer.notice_simple(params[:inquiry].to_s, title = '変なお問合せがありました。'))
    else
      inquiry = Inquiry.create!(inquiry_params)

      NoticeMailer.deliver_later(NoticeMailer.accepted_inquiry(inquiry))
      NoticeMailer.deliver_later(NoticeMailer.received_inquiry(inquiry))
    end

    flash[:notice] = Message.const[:accept_inquiry]

    redirect_to action: 'new'
  rescue => e

    @inquiry = Inquiry.new(inquiry_params)

    logging('fatal', request, { finish: 'Error Occurred', err_msg: e.message, backtrace: e.backtrace })

    @notice_msg = Message.const[:failed_inquiry]

    render action: 'new', status: 500 and return
  end

  private

  def inquiry_params
    params.require(:inquiry).permit(:name, :mail, :body, :user_id)
  end
end
