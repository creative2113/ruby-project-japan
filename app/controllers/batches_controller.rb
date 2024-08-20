class BatchesController < ApplicationController

  before_action :confirm_ip

  def request_search
    user_id = params[:user_id]
    req_id  = params[:search_request_id]

    if user_id.blank? || req_id.blank?
      render json: { result: 'not_exist_request' }, status: :bad_request and return
    end

    s_req = SearchRequest.find_by(id: req_id, user_id: user_id)

    if s_req.blank?
      render json: { result: 'not_exist_request' }, status: :bad_request and return
    end

    SearchWorker.perform_async(s_req.id)

    render json: { result: 'success' }, status: :ok and return
  rescue => e
    logging('error', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    render json: { result: 'error' }, status: :internal_server_error and return
  end

  def request_result_file
    user_id = params[:user_id].to_i
    result_file_id  = params[:result_file_id].to_i

    if user_id.blank? || result_file_id.blank?
      render json: { result: 'not_exist_result_file' }, status: :bad_request and return
    end

    result_file = ResultFile.find_by(id: result_file_id)

    if result_file.blank? || result_file.request.user.id != user_id
      render json: { result: 'not_exist_result_file' }, status: :bad_request and return
    end

    result_file.update!(status: ResultFile.statuses[:waiting])
    ResultFileWorker.perform_async(result_file.id)

    render json: { result: 'success' }, status: :ok and return
  rescue => e
    logging('error', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    render json: { result: 'error' }, status: :internal_server_error and return
  end

  def request_test_search
    user_id = params[:user_id]
    req_id  = params[:test_request_id]

    if user_id.blank? || req_id.blank?
      render json: { result: 'not_exist_request' }, status: :bad_request and return
    end

    req = Request.find_by(id: req_id, user_id: user_id)

    if req.blank? || !req.test
      render json: { result: 'not_exist_request' }, status: :bad_request and return
    end

    req.corporate_list_urls.test_mode.first.update!(status: EasySettings.status[:waiting])
    TestRequestSearchWorker.perform_async(req.id)

    render json: { result: 'success' }, status: :ok and return
  rescue => e
    logging('error', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })

    render json: { result: 'error' }, status: :internal_server_error and return
  end

  private

  def confirm_ip
    return if Rails.application.credentials.batch_server[:allow_request_ips].include?(request.remote_ip)

    render json: { result: 'forbidden' }, status: :forbidden and return
  end
end
