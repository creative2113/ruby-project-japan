class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable, :lockable

  has_many   :requests,          dependent: :destroy
  has_many   :search_requests,   dependent: :destroy
  has_many   :monthly_histories, dependent: :destroy
  has_many   :simple_investigation_histories, dependent: :destroy
  has_one    :billing,           dependent: :destroy
  has_one    :allow_ip,          dependent: :destroy
  has_one    :preferences,       dependent: :destroy, class_name: 'Preference'
  belongs_to :referrer, optional: true

  has_many :user_coupons
  has_many :coupons, through: :user_coupons

  enum referral_reason: [ :url, :coupon ], _prefix: true
  enum position: [ :general_employee, :section_chief, :manager, :board_member, :ceo ]
  enum role: [ :general_user, :public_user, :administrator ]

  validates_presence_of :company_name

  validates :family_name, presence: true, on: :create
  validates :given_name, presence: true, on: :create
  validates :department, presence: true, on: :create
  validates :position, presence: true, on: :create
  validates :tel, presence: true, on: :create
  validate  :check_user_data, on: :create
  validates :password, format: {with: /\A(?=.*?[a-zA-z])(?=.*?[0-9]).*\z/, message: :invalid_password_format}, on: :create
  validates :terms_of_service, acceptance: { message: :agree_to }, on: :create

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  def current_history
    MonthlyHistory.find_around(self.id)
  end

  def count_up
    history = current_history
    history.with_lock do
      history.search_count = history.search_count.nil? ? 1 : history.search_count + 1

      history.save!
    end
  end

  # 単体検索で使っている
  def over_current_activate_limit?
    code = [:administrator, :public].include?(my_plan) ? my_plan : current_history.plan_code
    SearchRequest.current_activate_count(self) >= EasySettings.access_current_limit[code]
  end

  # 2022/5/8 一旦廃止
  def over_access?
    self.update!(search_count: 0) if self.search_count.nil? || self.search_count < 0
    self.update!(latest_access_date: Time.zone.today) if self.latest_access_date.nil?

    if self.search_count >= EasySettings.access_limit[my_plan] && self.latest_access_date == Time.zone.today
      true
    else
      false
    end
  end

  def over_monthly_limit?
    history = current_history
    history.with_lock do
      history.update!(search_count: 0) if history.search_count.nil? || history.search_count < 0
    end

    if history.search_count >= EasySettings.monthly_access_limit[history.plan_code]
      true
    else
      false
    end
  end

  # 2022/5/8 一旦廃止、待機数制限に変更
  def request_limit?
    self.update!(request_count: 0) if self.request_count.nil? || self.request_count < 0
    self.update!(last_request_date: Time.zone.today) if self.last_request_date.nil?

    if self.request_count >= EasySettings.request_limit[my_plan] && self.last_request_date == Time.zone.today
      true
    else
      false
    end
  end

  def monthly_request_limit?
    history = current_history
    history.with_lock do
      history.update!(request_count: 0) if history.request_count.nil? || history.request_count < 0
    end

    if history.request_count >= EasySettings.monthly_request_limit[history.plan_code]
      true
    else
      false
    end
  end

  def request_count_up
    history = current_history
    history.with_lock do
      history.request_count = history.request_count.nil? ? 1 : history.request_count + 1

      history.save!
    end
  end

  def monthly_acquisition_limit?
    history = current_history
    history.update!(acquisition_count: 0) if history.acquisition_count.nil? || history.acquisition_count < 0

    if history.acquisition_count >= EasySettings.monthly_acquisition_limit[history.plan_code]
      true
    else
      false
    end
  end

  def monthly_simple_investigation_limit?
    history = current_history
    history.with_lock do
      history.update!(simple_investigation_count: 0) if history.simple_investigation_count.nil? || history.simple_investigation_count < 0
    end

    if history.simple_investigation_count >= EasySettings.simple_investigation_limit[history.plan_code]
      true
    else
      false
    end
  end

  def simple_investigation_count_up
    history = current_history
    history.with_lock do
      history.simple_investigation_count = history.simple_investigation_count.nil? ? 1 : history.simple_investigation_count + 1
      history.save!
    end
  end

  def my_plan
    if administrator?
      :administrator
    elsif public_user?
      :public
    elsif billing.current_plans.present?
      PlanConverter.convert_to_sym(billing.current_plans[0].name)
    else
      :free
    end
  end

  def my_plan_number
    EasySettings.plan[my_plan]
  end

  # def next_plan
  #   EasySettings.plan.invert[self.billing.next_plan]
  # end

  # def next_plan?
  #   !self.billing.next_plan.nil?
  # end

  # def plan
  #   self.billing.plan
  # end

  def available?(function)
    Availability.new(self, function).how?
  end

  def scheduled_stop?
    return false if billing.current_plans.blank?

    ( billing.credit? || billing.invoice? ) &&
    self.billing.current_plans[0].end_at.present?
  end

  def waiting?
    self.billing.current_plans.blank? && self.billing.next_enable_plan.present?
  end

  def trial?
    return false if self.billing.current_plans.blank?
    self.billing.current_plans[0].trial?
  end

  def current_plan_name
    return '管理者プラン' if administrator?
    billing.current_plans[0]&.name || '無料プラン'
  end

  def credit_payment?
    self.billing.credit?
  end

  def bank_payment?
    self.billing.bank_transfer?
  end

  def invoice_payment?
    self.billing.invoice?
  end

  def paid?
    self.billing.current_plans.present?
  end

  def unpaid?
    self.billing.current_plans.blank?
  end

  def referrer_trial_coupon
    user_coupons.where(coupon: Coupon.find_referrer_trial)[0]
  end

  def confirm_count_period
    billing = self.billing

    if billing.current_plans[0].blank? || administrator?
      confirm_count_period_for_free_or_admin
    elsif billing.credit? && paid?
      confirm_count_period_for_credit
    elsif billing.bank_transfer?
      confirm_count_period_for_bank
    elsif billing.invoice?
      confirm_count_period_for_invoice
    elsif trial?
      confirm_count_period_for_credit
    else
      # このパターンは想定外パターンなので、検知する => 後で対応
      Lograge.logging('error', { class: self.class.to_s, method: 'confirm_count_period', user: self.id, issue: "Strange billing 1: billing_id: #{billing.id} billing.payment_method: #{billing.payment_method}", backtrace: caller })
    end

    if MonthlyHistory.get_last(self).blank?
      # このパターンは想定外パターンなので、検知する => 後で対応
      Lograge.logging('error', { class: self.class.to_s, method: 'confirm_count_period', user: self.id, issue: "Strange billing 2: billing_id: #{billing.id} billing.payment_method: #{billing.payment_method}", backtrace: caller })
    end
  end

  def confirm_count_period_for_credit
    billing = self.billing

    return if !( billing.credit? && paid? ) &&
              !trial?

    plan = billing.current_plans[0]
    plan_num = EasySettings.plan[PlanConverter.convert_to_sym(plan.name).to_s]

    history_last = MonthlyHistory.get_last(self)

    if history_last.blank?
      history_last = MonthlyHistory.create!(user: self, plan: plan_num, start_at: Time.zone.now, end_at: expiration_date)
    elsif history_last.plan == EasySettings.plan[:free]
      start = if plan.trial?
        self.referrer_trial_coupon.created_at.beginning_of_day
      else
        plan.start_at
      end

      ActiveRecord::Base.transaction do
        history_last.update!(end_at: start - 1.seconds)
        MonthlyHistory.create!(user: self, plan: plan_num, start_at: start, end_at: next_planned_expiration_date || expiration_date)
      end
    elsif history_last.end_at < Time.zone.now

      # 数ヶ月飛ばす可能性もあるが、先月の終了日の次の日からとする
      start = if history_last.end_at.iso8601 == history_last.end_at.end_of_day.iso8601
        history_last.end_at.next_day.beginning_of_day
      else
        history_last.end_at + 1.seconds
      end

      end_at = expiration_date <= Time.zone.now ? next_planned_expiration_date : expiration_date
      history_last = MonthlyHistory.create!(user: self, plan: plan_num, start_at: start, end_at: end_at)
    elsif Time.zone.now <= history_last.end_at
      history_last.update_memo!(plan_num) unless history_last.plan == plan_num
    else
      # このパターンは想定外パターンなので、検知する => 後で対応
      Lograge.logging('error', { class: self.class.to_s, method: 'confirm_count_period_for_credit', user: self.id, issue: "Strange monthly history: history_last: #{history_last.end_at} expiration_date: #{expiration_date} Time.now: #{Time.zone.now}", backtrace: caller })
    end

  rescue => e
    Lograge.logging('fatal', { class: self.class.to_s, method: 'confirm_count_period_for_credit', user: self.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
  end

  def confirm_count_period_for_bank
    return unless billing.bank_transfer?
    return if ( plan = billing.current_plans[0] ).blank?

    plan_num = EasySettings.plan[PlanConverter.convert_to_sym(plan.name).to_s]

    expr_d = expiration_date.dup

    history_last = MonthlyHistory.get_last(self)

    if history_last.blank?
      start = Time.zone.now
      end_at = cal_end_at(start, expr_d)

      history_last = MonthlyHistory.create!(user: self, plan: plan_num, start_at: start, end_at: end_at)

    elsif history_last.plan == EasySettings.plan[:free]
      start  = plan.start_at
      end_at = cal_end_at(start, expr_d)

      ActiveRecord::Base.transaction do
        history_last.update!(end_at: start - 1.seconds)
        MonthlyHistory.create!(user: self, plan: plan_num, start_at: start, end_at: end_at)
      end

    elsif Time.zone.now <= history_last.end_at
      history_last.update_memo!(plan_num) unless history_last.plan == plan_num
    else
      start = plan.start_at <= history_last.end_at ? history_last.end_at + 1.seconds : plan.start_at
      end_at = cal_end_at(start, expr_d)

      MonthlyHistory.create!(user: self, plan: plan_num, start_at: start, end_at: end_at)
    end

  rescue => e
    Lograge.logging('fatal', { class: self.class.to_s, method: 'confirm_count_period_for_bank', user: self.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
  end

  def cal_end_at(start_time, exp_date)
    dif = ((Time.zone.now - start_time)/1.months).to_i - 1

    end_at = Time.zone.now
    dif.upto(dif+3) do |i|
      end_at = (start_time + i.months - 1.day).end_of_day
      end_at = exp_date if exp_date < end_at
      break puts "cal_end_at = ##{i}, dif = ##{dif}" if Time.zone.now < end_at
    end
    raise '超過せず。。' unless Time.zone.now < end_at
    end_at
  end

  def confirm_count_period_for_invoice
    return unless billing.invoice?

    return if ( plan = billing.current_plans[0] ).blank?
    plan_num = EasySettings.plan[PlanConverter.convert_to_sym(plan.name).to_s]

    expr_date = next_planned_expiration_date&.dup || expiration_date.dup

    # #next_planned_expiration_dateも#expiration_dateも
    # end_atがあり、かつ、end_atが先の場合は、end_atが出力されるようなっているので、
    # このような対策は不要なのだが、念の為
    if plan.end_at.present? && plan.end_at.iso8601 < expr_date.iso8601
      expr_date = plan.end_at
    end

    history_last = MonthlyHistory.get_last(self)

    if history_last.blank?
      MonthlyHistory.create!(user: self, plan: plan_num, start_at: plan.start_at, end_at: expr_date)

    elsif history_last.plan == EasySettings.plan[:free]

      ActiveRecord::Base.transaction do
        history_last.update!(end_at: plan.start_at - 1.seconds)
        MonthlyHistory.create!(user: self, plan: plan_num, start_at: plan.start_at, end_at: expr_date)
      end

    elsif Time.zone.now <= history_last.end_at
      history_last.update_memo!(plan_num) unless history_last.plan == plan_num
    else
      start = history_last.end_at + 1.seconds

      MonthlyHistory.create!(user: self, plan: plan_num, start_at: start, end_at: expr_date)
    end

  rescue => e
    Lograge.logging('fatal', { class: self.class.to_s, method: 'confirm_count_period_for_invoice', user: self.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
  end

  def confirm_count_period_for_free_or_admin
    return nil if !administrator? && billing.current_plans[0].present?

    history_last = MonthlyHistory.get_last(self)

    plan_num = administrator? ? EasySettings.plan[:administrator] : EasySettings.plan[:free]

    if history_last.blank?
      MonthlyHistory.create!(user: self, plan: plan_num, start_at: Time.zone.now.beginning_of_month, end_at: Time.zone.now.end_of_month)

    elsif Time.zone.now <= history_last.end_at
      unless history_last.plan == plan_num
        # このパターンは想定外パターンなので、検知する => 後で対応
        Lograge.logging('error', { class: self.class.to_s, method: 'confirm_count_period_for_free_or_admin', user: self.id, issue: "Strange monthly history: history_last: #{history_last.end_at} history_last_plan: #{history_last.plan}", backtrace: caller })
      end
    else
      start = Time.zone.now.beginning_of_month <= history_last.end_at ? history_last.end_at + 1.seconds : Time.zone.now.beginning_of_month
      MonthlyHistory.create!(user: self, plan: plan_num, start_at: start, end_at: Time.zone.now.end_of_month)
    end

    true
  rescue => e
    Lograge.logging('fatal', { class: self.class.to_s, method: 'confirm_count_period', user: self.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
  end

  def confirm_billing_status

    confirm_count_period

  rescue => e
    Lograge.logging('fatal', { class: self.class.to_s, method: 'confirm_billing_status', user: self.id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
  end

  def expiration_date
    return nil if billing.current_plans.blank?
    current_plan = billing.current_plans[0].dup

    if billing.credit? || billing.invoice?
      # クレジットと請求書ではfuture_planは見ない
      date = current_plan.next_charge_date.present? ? current_plan.next_charge_date&.yesterday&.end_of_day : current_plan.cal_next_charge_date&.yesterday&.end_of_day
      date = current_plan.end_at if ( date.blank? || ( current_plan.end_at.present? && current_plan.end_at < date ) )
      date
    elsif billing.bank_transfer?
      if billing.future_plans.present?
        billing.future_plans[-1].end_at
      else
        current_plan.end_at
      end
    elsif billing.bonus?
      if billing.future_plans.present?
        billing.future_plans[-1].end_at
      else
        current_plan.end_at
      end
    end
  end

  # 更新日が過ぎているが、まだ更新処理が終わっていない時に、予定している次の期限日を出す
  def next_planned_expiration_date
    return nil unless ( billing.credit? || billing.invoice? )
    return nil if billing.current_plans.blank?
    current_plan = billing.current_plans[0]

    # 期限切れを確認
    if current_plan.next_charge_date.present? &&
       current_plan.next_charge_date.beginning_of_day <= Time.zone.now

      # プランは継続することを確認
      if current_plan.end_at.nil?
        return current_plan.cal_next_charge_date.yesterday.end_of_day

      elsif current_plan.end_at.present? && Time.zone.now.end_of_day < current_plan.end_at
        return ( current_plan.cal_next_charge_date&.yesterday&.end_of_day || current_plan.end_at )
      end
    end
    nil
  end

  private

  def check_user_data
    if family_name.present? && ( family_name.hyper_strip.size < 1 || family_name.hyper_strip.size > 20 )
      errors.add(:family_name, 'を正しく入力してください。')
    end

    if given_name.present? && ( given_name.hyper_strip.size < 1 || given_name.hyper_strip.size > 20 )
      errors.add(:given_name, 'を正しく入力してください。')
    end

    if tel.present? && ( tel.hyper_strip.size < 7 || tel.hyper_strip.size > 20 )
      errors.add(:tel, 'を正しく入力してください。')
    end
  end

  class << self
    def get_public
      self.find_by_email(Rails.application.credentials.user[:public][:email])
    end

    def public_id
      self.get_public.id
    end
  end
end
