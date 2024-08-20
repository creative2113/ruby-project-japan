class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_cookie_referrer_url

  # 例外処理
  unless Rails.env.development?
    rescue_from Exception, with: :_render_500
    rescue_from AbstractController::ActionNotFound, with: :_render_404
    rescue_from ActionController::RoutingError, with: :_render_404
    rescue_from ActiveRecord::RecordNotFound, with: :_render_404
    rescue_from ActiveRecord::RecordInvalid, with: :_render_422
    rescue_from ActiveRecord::RecordNotSaved, with: :_render_422
  end

  def routing_error
    raise ActionController::RoutingError, params[:path]
  end

  def append_info_to_payload(payload)
    super
    payload[:ip]             = request.remote_ip
    payload[:uuid]           = request.uuid
    payload[:referer]        = request.referer
    payload[:user_agent]     = request.user_agent

    payload[:session_id]     = session[:session_id]
    payload[:current_user]   = current_user.nil? ? User.get_public : current_user
    payload[:user_signed_in] = user_signed_in?
  end

  def check_admin
    _render_404 and return unless current_user&.administrator? && current_user.allow_ip&.allow?(request.remote_ip)
  end

  protected

  def configure_permitted_parameters
    # account_updateのときに、各パラメータをストロングパラメータに追加する
    devise_parameter_sanitizer.permit(:account_update, keys: [:company_name, :family_name, :given_name, :department, :position, :tel, :terms_of_service])
  end

  def controller_and_action
    "#{params[:controller].camelize}Controller:#{params[:action]}"
  end

  private

  def confirm_billing_status
    current_user.confirm_billing_status if user_signed_in?
  end

  def set_cookie_referrer_url
    return unless request.request_method == 'GET'
    return if user_signed_in?

    return if ( referrer_id = params[:rfd] ).blank?

    cookies.encrypted[:rfd] = {
      value: referrer_id,
      expires: Time.zone.now + 30.days
    }
  end

  def _render_404(e = nil)
    if request.format.to_sym == :json
      render json: { error: '404 Not Found' }, status: 404
    else
      render template: 'errors/error_404', status: 404, layout: 'application', content_type: 'text/html'
    end
  end

  def _render_422(e = nil)
    if request.format.to_sym == :json
      render json: { error: '422 Unprocessable Entity' }, status: 404
    else
      render template: 'errors/error_422', status: 422, layout: 'application', content_type: 'text/html'
    end
  end

  def _render_500(e = nil)
    logging('error', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    if request.format.to_sym == :json
      render json: { error: '500 Internal Server Error' }, status: 500
    else
      render template: 'errors/error_500', status: 500, layout: 'application', content_type: 'text/html'
    end
  end
end
