# 定期課金を日次で回すバッチ処理

class BillingWorker

  class PayJpChargeError < StandardError; end

  class << self

    def all_execute(time = Time.zone.now)
      invoice_issue_res = []
      end_plan_res      = []
      start_plan_res    = []
      charge_res        = []

      invoice_issue_res = if time.day == 1
        res = issue_invoice(time.last_month)
        res.unshift('請求書発行プロセス実行')
        res
      else
        ['請求書発行プロセス不実行']
      end

      # プランが終了予定のものを終了させる
      end_plan_res = execute_plan_end(time)
      end_plan_res.unshift('プラン終了一覧')

      # プランが開始していないものを開始する
      start_plan_res = execute_plan_start(time)
      end_plan_res.unshift('プラン開始一覧')

      charge_res = execute_charge(time)
      end_plan_res.unshift('課金一覧')

      NoticeMailer.deliver_later(NoticeMailer.notice_simple("ビリングワーカー 完了\n\n#{invoice_issue_res.join("\n")}\n\n\n#{charge_res.join("\n")}\n\n\n#{end_plan_res.join("\n")}\n\n\n#{start_plan_res.join("\n")}", 'ビリング', 'バッチ'))
    rescue => e
      Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'all_execute', { issue: 'all_execute エラー', time: time, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      NoticeMailer.deliver_later(NoticeMailer.notice_simple("ビリングワーカー エラーによる途中終了\n\n#{invoice_issue_res.join("\n")}\n\n\n#{charge_res.join("\n")}\n\n\n#{end_plan_res.join("\n")}\n\n\n#{start_plan_res.join("\n")}", 'ビリング', 'バッチ'))
    end

    # 請求書を発行する月を指定する。5月分の使用料の請求書を発行するなら、5月の日を指定
    def issue_invoice(time = Time.zone.now)
      res = []
      s3_client = S3Handler.new

      BillingHistory.invoices_by_month(time).group_by { |history| history.billing_id }.each do |bil_id, billing_histories|
        billing = nil
        next if billing_histories.blank?

        next if ( billing = Billing.find(bil_id) ).blank?

        next if ( invoice_pdf = InvoicePdf.new(billing.user.company_name, billing_histories, time) ).blank?

        # tmpディレクトリ生成
        Dir.mktmpdir do |dir|
          path = "#{dir}/invoice.pdf"
          IO.write(path, invoice_pdf.render, mode: 'wb')

          s3_path = "#{Rails.application.credentials.s3_bucket[:invoices]}/#{billing.user.id}/invoice_#{time.strftime("%Y%m")}.pdf"

          upload_to_s3(s3_client, s3_path, path)
        end

        res << "USER_ID: #{billing.user.id}, FILE_NAME: invoice_#{time.strftime("%Y%m")}.pdf"
      rescue => e
        Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'issue_invoice', { issue: 'issue_invoice 個別エラー', user_id: billing&.user_id, billing_id: billing&.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      end
      res
    rescue => e
      Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'issue_invoice', { issue: 'issue_invoice エラー', time: time, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      res
    end

    def upload_to_s3(s3_client, s3_path, file_path)
      20.times do |i|
        break if s3_client.upload(s3_path: s3_path, file_path: file_path)
        raise 'S3 Upload Error' if i > 15
        sleep 2
      end
    end

    def execute_charge(time = Time.zone.now)
      res = []
      today_charge_plans = BillingPlan.charge_on_date(time.to_date)
      today_charge_plans.each do |plan|
        ActiveRecord::Base.transaction do
          next unless ( plan.billing.credit? || plan.billing.invoice? )

          amount = plan.charge_and_status_update_by_credit(time)
          next if amount.blank? || amount < 50

          try_charge(plan, amount) if plan.billing.credit?

          # トライアルの場合は解除する
          plan.update!(trial: false) if plan.trial?

          BillingHistory.create!(item_name: plan.name, payment_method: plan.billing.payment_method, price: amount, billing_date: time.to_date, unit_price: amount, number: 1, billing: plan.billing)
          res << "PLAN_ID: #{plan&.id}, TYPE: #{plan&.type}, CHARGE_DATE: #{plan&.charge_date}, AMOUNT: #{amount&.to_i&.to_s(:delimited)}円"
        rescue PayJpChargeError => e
        rescue Billing::PayJpCardChargeFailureError => e
        rescue => e
          Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'execute_charge', { issue: 'execute_charge 個別エラー', user_id: plan.billing.user_id, plan_id: plan.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
          content = "USER_ID[#{plan.billing.user_id}] PLAN_ID[#{plan.id}]: BillingWorker execute_charge 個別エラー] CUSTOMER[#{plan.billing.customer_id}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
          NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
        end
      end
      res
    rescue => e
      Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'execute_charge', { issue: 'execute_charge エラー', time: time, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      res
    end

    def execute_plan_start(time = Time.zone.now)
      res = []
      BillingPlan.starting(time).each do |plan|
        if plan.billing.credit? || plan.billing.invoice?
          if plan.next_charge_date.blank?
            plan.update!(status: :ongoing, next_charge_date: time.to_date)
          else
            plan.update!(status: :ongoing)
          end
        else
          plan.update!(status: :ongoing)
        end

        res << "USER_ID: #{plan.billing.user.id}, PLAN_ID: #{plan.id}"
      rescue => e
        Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'execute_plan_start', { issue: 'execute_plan_start 個別エラー', user_id: plan.billing.user_id, plan_id: plan.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      end
      res
    rescue => e
      Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'execute_plan_start', { issue: 'execute_plan_start エラー', time: time, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      res
    end

    def execute_plan_end(time = Time.zone.now)
      res = []
      BillingPlan.ending(time).each do |plan|
        ActiveRecord::Base.transaction do
          plan.update!(status: :stopped)
          plan.billing.update!(payment_method: nil) if plan.billing.current_plans.blank?
        end

        res << "USER_ID: #{plan.billing.user.id}, PLAN_ID: #{plan.id}"
      rescue => e
        Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'execute_plan_end', { issue: 'execute_plan_end 個別エラー', user_id: plan.billing.user_id, plan_id: plan.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      end
      res
    rescue => e
      Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'execute_plan_end', { issue: 'execute_plan_end エラー', time: time, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      res
    end

    def try_charge(plan, amount)
      res = nil
      Billing.try_connection do
        res = plan.billing.create_charge(amount)
      end
    rescue Billing::PayJpCardChargeFailureError => e
      # 要対応　問題(中) -> 2,3日中に対応
      Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'try_charge', { issue: 'PAYJP Charge Failure: 課金の失敗: カード認証・支払いエラーによる失敗', user_id: plan.billing.user_id, plan_id: plan.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      content = "USER_ID[#{plan.billing.user_id}] PLAN_ID[#{plan.id}]: PAYJP Charge Failure: カード認証・支払いエラーによる失敗。] CUSTOMER[#{plan.billing.customer_id}] RESPONSE[#{res}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
      raise Billing::PayJpCardChargeFailureError
    rescue => e
      # 要対応　問題(中) -> 2,3日中に対応
      Lograge.job_logging('Workers', 'fatal', 'BillingWorker', 'try_charge', { issue: 'PAYJP Charge Failure: 課金の失敗', user_id: plan.billing.user_id, plan_id: plan.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
      content = "USER_ID[#{plan.billing.user_id}] PLAN_ID[#{plan.id}]: PAYJP Charge Failure: 課金の失敗。] CUSTOMER[#{plan.billing.customer_id}] RESPONSE[#{res}] ERR_CLASS[#{e.class}] ERR_MSG[#{e.message}] BACKTRACE[#{e.backtrace}]"
      NoticeMailer.deliver_later(NoticeMailer.notice_emergency_fatal(content, :error))
      raise PayJpChargeError
    end
  end
end
