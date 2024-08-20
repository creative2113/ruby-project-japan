class PaymentHistoriesController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user&.billing&.histories.present?
      @last_month = current_user.billing.last_history&.billing_date.to_time

      @last_month_histories = current_user.billing.histories.by_month(@last_month)

      @history_months = current_user.billing.history_months

      @invoice_download_display = if !@last_month_histories.any? { |his| his.invoice? }
        false
      elsif Time.zone.now <= @last_month.end_of_month
        false
      elsif @last_month.next_month.beginning_of_month < Time.zone.now && Time.zone.now < @last_month.next_month.beginning_of_month.tomorrow
        exist_invoice_file?(@last_month)
      else
        true
      end
    else
      redirect_back fallback_location: root_path and return
    end
  end

  def show
    date = "#{params[:month]}01".to_time
    target_histories = current_user.billing&.histories&.by_month(date)

    if target_histories.blank?
      render json: { error: 'データは存在しません。' }, status: :bad_request and return
    end

    invoice = target_histories.any? { |his| his.invoice? }

    end_of_month = date.end_of_month.strftime("%FT%T%:z")

    render json: { year_month: params[:month], end_of_month: end_of_month, invoice: invoice, title: "#{date.strftime("%Y年%-m月")} 課金情報",
                   invoice_file_exist: invoice && exist_invoice_file?(date), data: serialize(target_histories) }, status: :ok
  end

  def download
    date = "#{params[:month]}01".to_time

    if Time.zone.now <= date.end_of_month
      render json: { error: 'まだ請求書は作成されていません。' }, status: :bad_request and return
    end

    file_path = invoice_s3_path(date)
    data = S3Handler.new.download(s3_path: file_path).body

    respond_to do |format|
      format.pdf do
        send_data(data.read, filename: file_path.split('/')[-1], disposition: 'inline', type: 'application/pdf')
      end
    end
  rescue Aws::S3::Errors::NoSuchKey => e
    if date.next_month.beginning_of_month.tomorrow <= Time.zone.now
      # 管理側にファイルが存在しないことを通知する
      content = "請求書ファイルが存在しません。至急、確認が必要です。[#{session[:session_id]}] IP[#{request.remote_ip}] USER_ID[#{current_user.id}] ERROR_POINT[#{controller_and_action}] DATE_MONTH[#{params[:month]}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
      render json: { error: '請求書ファイルが存在しません。' }, status: :bad_request and return
    else
      render json: { error: 'まだ請求書は作成されていません。本日中には作成される予定です。しばらく経ってから再度お試しください。' }, status: :bad_request and return
    end
  rescue => e
    @finish_status = :error
    logging('fatal', request, { finish: 'Invoice Download Failure', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    render json: { error: 'エラーが発生しました。' }, status: :internal_server_error and return
  end

  private

  def exist_invoice_file?(month)
    if month.next_month.beginning_of_month.tomorrow <= Time.zone.now # 次の月の2日を超えている時
      true
    elsif month.end_of_month < Time.zone.now
      S3Handler.new.exist_object?(s3_path: invoice_s3_path(month))
    else
      false
    end
  end

  def invoice_s3_path(time)
    "#{Rails.application.credentials.s3_bucket[:invoices]}/#{current_user.id}/invoice_#{time.strftime("%Y%m")}.pdf"
  end

  def serialize(histories)
    histories.map do |history|
      {
        billing_date:   history.billing_date&.strftime("%Y年%-m月%-d日"),
        item_name:      history.item_name,
        payment_method: history.payment_method_str,
        unit_price:     "#{history.unit_price&.to_s(:delimited)}円",
        number:         history.number&.to_s(:delimited),
        price:          "#{history.price&.to_s(:delimited)}円",
      }
    end
  end
end
