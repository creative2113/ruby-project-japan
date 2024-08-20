class Billing < ApplicationRecord

  class PayJpCardChargeFailureError < StandardError; end
  class StrangeParametersError < StandardError; end
  class ManyRetryError < StandardError; end
  class RetryError < StandardError; end

  belongs_to :user
  has_many :plans, class_name: 'BillingPlan'
  has_many :histories, class_name: 'BillingHistory'

  Payjp::api_key = Rails.application.credentials.payment[:payjp_private_key]

  enum status: [ :unpaid, :paid, :paused, :waiting, :stop, :trial, :scheduled_stop ]
  enum payment_method: [ :credit, :bank_transfer, :bonus, :invoice ]

  scope :invoices, -> do
    where(payment_method: :invoice)
  end

  def to_log
    "USER_ID: #{user_id}, billing_id: #{id}, plan: #{plan} last_plan: #{last_plan}, next_plan: #{next_plan}, status: #{status}, payment_method: #{payment_method}, first_paid_at: #{first_paid_at}, last_paid_at: #{last_paid_at}, expiration_date: #{expiration_date}"
  end

  def current_plans
    plans.current
  end

  def future_plans
    plans.where('start_at > ? ', Time.zone.now.end_of_day).order(start_at: :asc)
  end

  def past_plans
    plans.where('end_at < ? ', Time.zone.now).order(end_at: :desc)
  end

  def next_enable_plan
    future_plans[0]
  end

  def last_history
    histories.order(billing_date: :desc)[0]
  end

  def this_month_histories
    histories.by_month(Time.zone.now)
  end

  def history_months
    histories.order(billing_date: :desc).pluck(:billing_date).map { |d| d.strftime("%Y年%-m月") }.uniq
  end

  def get_subscription_info
    Payjp::Subscription.retrieve(self.subscription_id)
  end

  def get_customer_info
    Payjp::Customer.retrieve(self.customer_id)
  end

  #
  # 顧客を登録する
  #
  def create_customer(token)
    customer = Payjp::Customer.create(
      card: token,
      email: self.user.email,
      metadata: { user_id: self.user.id, company_name: self.user.company_name, environment: Rails.env }
    )
    self.customer_id = customer.id # ここでは保存しない
    customer
  end

  #
  # 定額課金を作成する
  #
  def create_subscription(plan)
    Payjp::Subscription.create(
      customer: self.customer_id,
      plan:     plan
    )
  end

  #
  # 定額課金をお試し期間付きで作成する
  #
  def create_subscription_with_trial(plan, trial_end_at)
    Payjp::Subscription.create(
      customer:  self.customer_id,
      plan:      plan,
      trial_end: trial_end_at.to_i
    )
  end

  #
  # 定額課金を変更する
  #
  def change_subscription(new_plan_id)
    subscription           = Payjp::Subscription.retrieve(self.subscription_id)
    subscription.plan      = new_plan_id
    subscription.trial_end = self.expiration_date.to_i unless self.expiration_date.nil?
    subscription.save
  end

  #
  # 定期課金を削除する
  #
  def delete_subscription
    subscription = Payjp::Subscription.retrieve(self.subscription_id)
    subscription.delete
  end

  #
  # 課金を実行する
  #
  def create_charge(amount)
    Payjp::Charge.create(
      amount: amount.to_i,
      customer: self.customer_id,
      currency: 'jpy'
    )
  end

  #
  # 課金履歴を取得する
  #
  def get_charges(limit = 10, since_num = nil, until_num = nil)
    limit = 100 if limit > 100
    data = {customer: customer_id, limit: limit}
    data[:since] = (Time.zone.now - since_num.days).to_i if since_num.present?
    data[:until] = (Time.zone.now - until_num.days).to_i if until_num.present?
    Payjp::Charge.all(data)
  end

  #
  # 顧客を削除する
  #   顧客を削除すれば、紐づく定期課金も削除される
  #
  def delete_customer
    customer = Payjp::Customer.retrieve(self.customer_id)
    customer.delete
  end

  #
  # user_idを元に顧客を検索する
  #
  # since_num(何日前から)と, until_num(何日前まで)の検索範囲を絞る。(since_num　-> until_num)
  def search_customer(since_num = 7, until_num = -1)
    res = nil
    get_count = nil
    count = 0
    while get_count != 0
      customers = Payjp::Customer.all(limit: 100,
                                      offset: count * 100,
                                      since: (Time.zone.now - since_num.days).to_i,
                                      until: (Time.zone.now - until_num.days).to_i)
      get_count = customers.count.to_i
      customers.data.each do |cus|

        begin
          cus.metadata.user_id
        rescue => e
          next
        end

        if self.user.id == cus.metadata.user_id.to_i
          res       = cus
          get_count = 0
          break
        end
      end
      count += 1
    end
    res
  end

  #
  # user_idを元に顧客を検索する
  #
  # since_num(何日前から)と, until_num(何日前まで)の検索範囲を絞る。(since_num　-> until_num)
  def search_customer_by_email(environment = Rails.env, since_num = 7, until_num = -1)
    res = nil
    get_count = nil
    count = 0
    while get_count != 0
      customers = Payjp::Customer.all(limit: 100,
                                      offset: count * 100,
                                      since: (Time.zone.now - since_num.days).to_i,
                                      until: (Time.zone.now - until_num.days).to_i)
      get_count = customers.count.to_i
      customers.data.each do |cus|

        begin
          cus.metadata.environment
        rescue => e
          next
        end

        if cus.metadata.environment == environment && cus.email == self.user.email
          res       = cus
          get_count = 0
          break
        end
      end
      count += 1
    end
    res
  end

  def clean_customer_by_email
    raise 'テスト環境以外では利用禁止！！' unless Rails.env.test? # テスト環境以外利用禁止

    res = search_customer_by_email(Rails.env, 1, -1)
    res.delete if res.present?
  end

  def clean_customer(since_num = 7, until_num = 0)
    raise 'テスト環境以外では利用禁止！！' unless Rails.env.test? # テスト環境以外利用禁止

    get_count = nil
    count = 0
    del_count = 0
    while get_count != 0
      customers = Payjp::Customer.all(limit: 100,
                                      offset: count * 100,
                                      since: (Time.zone.now - since_num.days).to_i,
                                      until: (Time.zone.now - until_num.days).to_i)
      get_count = customers.count.to_i
      customers.data.each do |cus|

        begin
          cus.metadata.user_id
        rescue => e
          next
        end

        if self.user.id == cus.metadata.user_id.to_i
          cus.delete
          del_count += 1
        end
      end
      count += 1
    end
    puts "削除数: #{del_count}"
    del_count
  end

  def get_card_info(num = 1)
    customer = get_customer_info
    card     = customer.cards.all(limit: num, offset: 0)
    customer.cards.retrieve(card.data[num-1].id)
  end

  def get_card_count
    customer = get_customer_info
    card     = customer.cards.all(limit: 10, offset: 0)
    card.count
  end

  def delete_card(card_id)
    customer = get_customer_info
    card     = customer.cards.retrieve(card_id)
    card.delete
  end

  def create_card(card_token)
    get_customer_info.cards.create(
      card: card_token,
      default: true
    )
  end

  def get_current_service_end
    Time.zone.at(get_subscription_info.current_period_end)
  end

  def create_plan!(plan_id, charge_date: nil, start_at: Time.zone.now, end_at: nil, trial: false)

    status = if start_at.blank?
      raise StrangeParametersError, 'start_atがnil。'
    elsif Time.zone.now < start_at
      :waiting
    elsif end_at.present? && start_at < end_at && end_at <= Time.zone.now
      :stopped
    elsif end_at.present? && end_at <= start_at
      raise StrangeParametersError, 'start_atとend_atが間違っている可能性がある。'
    elsif start_at <= Time.zone.now
      :ongoing
    else
      raise StrangeParametersError, 'start_atとend_atが間違っている可能性がある。'
    end

    master_plan = MasterBillingPlan.find(plan_id)

    charge_date ||= if master_plan.annually?
      start_at.strftime("%m/%d")
    else
      start_at.day
    end

    plan = BillingPlan.new(billing_id: id,
                           name: master_plan.name,
                           status: status,
                           price: master_plan.price,
                           tax_included: master_plan.tax_included,
                           tax_rate: master_plan.tax_rate,
                           type: master_plan.type,
                           charge_date: charge_date,
                           start_at: start_at,
                           end_at: end_at,
                           trial: trial,
                          )

    next_charge_date = case status
    when :waiting
      plan.cal_next_charge_date(start_at - 1.day)
    when :ongoing
      charge_date.to_i == Time.zone.now.day ? Time.zone.today : plan.cal_next_charge_date
    when :stopped
      nil
    end

    plan.next_charge_date = next_charge_date
    plan.save!
  end

  # def change_plan!(new_plan_id)
  #   end_at = Time.zone.now - 2.second
  #   current_plan.update!(end_at: end_at)

  #   create_plan!(new_plan_id, charge_date: current_plan.type.charge_date, start_at: end_at - 1.second, end_at: current_plan.end_at)
  # end

  # def over_expiration_date?
  #   return true if self.expiration_date.nil?

  #   self.expiration_date < Time.zone.now
  # end

  # def plan_downgrading?
  #   next_enable_plan.present? && !over_expiration_date?
  # end

  # def should_downgrade_plan_now?
  #   next_enable_plan.present? && over_expiration_date?
  # end

  def create_new_subscription(plan_num, payjp_response)

    if payjp_response.status == 'active'
      status = self.class.statuses[:paid]
      first_paid_at = Time.zone.now
    elsif payjp_response.status == 'trial'
      status = self.class.statuses[:trial]
      first_paid_at = nil
    else
      raise 'Strange Status'
    end

    update(plan: plan_num,
           status: status,
           payment_method: self.class.payment_methods[:credit],
           customer_id: payjp_response.customer,
           subscription_id: payjp_response.id,
           first_paid_at: first_paid_at,
           expiration_date: Time.zone.at(payjp_response.current_period_end))
  end

  def set_bank_transfer_plan(master_plan_id, expiration_date)
    plan = create_plan!(master_plan_id, end_at: expiration_date)

    update!(payment_method: self.class.payment_methods[:bank_transfer],
            customer_id: nil,
            subscription_id: nil)
  end

  def set_invoice_plan(master_plan_id, start_date)
    plan = create_plan!(master_plan_id, charge_date: start_date.day, start_at: start_date)

    update!(payment_method: self.class.payment_methods[:invoice],
            customer_id: nil,
            subscription_id: nil)
  end

  class << self

    def plan_list
      EasySettings.plan_list
    end

    def try_connection(interval_sec = 3, retry_count = 100)
      retry_count = 15 if retry_count < 15
      retry_count.times do |i|
        res = yield i

        if res['error']
          if res['error']['status'] == 429 # レートリミットによるアクセス一時拒否でやり直し
            raise ManyRetryError, 'Error try many times but fail.' if i > retry_count - 5
            sleep interval_sec
          elsif res['error']['status'] == 402 # カード認証・支払いエラー
            raise PayJpCardChargeFailureError, 'カード認証・支払いエラー'
          else
            raise RetryError, 'Error Response Return'
          end
        else
          break
        end
      end
    end

    def create_dummy_card_token(num = '4242424242424242', month = '12', year = '2040', csv = '123')
      Payjp::Token.create({
        card: {
          number: num,
          cvc: csv,
          exp_month: month,
          exp_year: year
        }},
        {
          'X-Payjp-Direct-Token-Generate': 'true'
        }
      )
    end

    def get_charges(customer_id, limit = 10, since_num = nil, until_num = nil)
      limit = 100 if limit > 100
      data = {customer: customer_id, limit: limit}
      data[:since] = (Time.zone.now - since_num.days).to_i if since_num.present?
      data[:until] = (Time.zone.now - until_num.days).to_i if until_num.present?
      Payjp::Charge.all(data)
    end

    def get_subscription(subscription_id)
      Payjp::Subscription.retrieve(subscription_id)
    end

    def get_last_charge_data
      30.times do |i|
        res = Payjp::Charge.all(limit: 10, offset: 10*i )

        res['data'].each do |data|
          return data if data.subscription.nil?
        end
      end
    end

    def get_subscription_info(subscription_id)
      Payjp::Subscription.retrieve(subscription_id)
    end

    def get_customer_info(customer_id)
      Payjp::Customer.retrieve(customer_id)
    end

    def delete_customers(limit, offset)
      return if Rails.env.production? || Rails.env.dev?
      res = Payjp::Customer.all(limit: limit, offset: offset)
      res['data'].each do |data|
        begin
          next unless data.metadata.environment == 'test'
        rescue => e
          next
        end
        customer = Payjp::Customer.retrieve(data['id'])
        customer.delete
      end
    end

    # def delete_subscriptions(limit)
    #   return if Rails.env.production? || Rails.env.dev?
    #   res = Payjp::Subscription.all(limit: limit)
    #   res['data'].each do |data|
    #     subscription = Payjp::Subscription.retrieve(data['id'])
    #     subscription.delete
    #   end
    # end
  end
end
