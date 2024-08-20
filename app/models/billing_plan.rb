class BillingPlan < ApplicationRecord
  self.inheritance_column = :_type_disabled # typeを使えるようにする

  belongs_to :billing

  enum type: [:dayly, :weekly, :monthly, :quarterly, :annually]
  enum status: [ :waiting, :ongoing, :stopped ]

  scope :current, -> do
    now = Time.zone.now
    where('( start_at <= ? AND ? <= end_at ) OR ( start_at <= ? AND end_at IS NULL )', now, now, now)
  end

  scope :search_by_time, -> (time) do
    where('( start_at <= ? AND ? <= end_at ) OR ( start_at <= ? AND end_at IS NULL )', time, time, time)
  end

  scope :charge_on_date, -> (date = Time.zone.today) do
    where(next_charge_date: date)
  end

  scope :starting, -> (time = Time.zone.now) do
    where(status: [:waiting]).where('start_at <= ?', time)
  end

  scope :ending, -> (time = Time.zone.now) do
    where.not(status: :stopped).where('end_at <= ?', time)
  end


  validates :billing_id, presence: true
  validates :price, presence: true
  validates :start_at, presence: true
  validates :type, presence: true
  validates :charge_date, presence: true
  validate :check_time_range
  validate :check_charge_date


  def charge_day?(time = Time.zone.now)
    next_charge_date == time.to_date
  end

  def charge_and_status_update_by_credit(time = Time.zone.now)
    return nil unless charge_day?(time)

    amount = 0
    case status
    when 'waiting'
      if start_at < time
        amount = cal_amount
        update!(status: :ongoing, next_charge_date: cal_next_charge_date(time), last_charge_date: time)
      end
    when 'ongoing'
      if end_at.present? && end_at < time
        update!(status: :stopped, next_charge_date: nil)
      else
        amount = cal_amount
        update!(next_charge_date: cal_next_charge_date(time), last_charge_date: time)
      end
    when 'stopped'
      update!(end_at: time.yesterday.end_of_day) if end_at.nil?
      update!(next_charge_date: nil) if next_charge_date.present?
    end
    amount
  end

  # end_atを設定するだけでOK
  def stop_at_next_update_date!(base_date = Time.zone.now)
    update!(end_at: cal_next_charge_date(base_date)&.yesterday&.end_of_day)
  end

  def cal_amount
    tax_included ? price : ( price + price * tax_rate / 100.to_f ).floor
  end

  # base_dateの当日は含まれない。base_dateから次の日以降で探すので、注意。
  # 存在しない日の場合は次の月の1日　例) 4/31は存在しないので、5/1になる
  def cal_next_charge_date(base_date = Time.zone.now)
    if monthly?
      if base_date.day < charge_date.to_i # 今月
        next_date = Time.zone.parse("#{base_date.strftime('%Y/%m')}/#{charge_date}").beginning_of_day

        next_date = base_date.next_month.beginning_of_month unless next_date.month == base_date.month
      else
        next_date = Time.zone.parse("#{base_date.next_month.strftime('%Y/%m')}/#{charge_date}").beginning_of_day

        next_date = next_date.beginning_of_month unless next_date.month == base_date.next_month.month
      end
    elsif annually?
      # 注) 閏年以外の2/29は3/1になる

      if base_date < Time.zone.parse("#{base_date.strftime('%Y')}/#{charge_date}").beginning_of_day # 今年
        next_date = Time.zone.parse("#{base_date.strftime('%Y')}/#{charge_date}").beginning_of_day
      else
        next_date = Time.zone.parse("#{base_date.next_year.strftime('%Y')}/#{charge_date}").beginning_of_day
      end
    end

    return nil if end_at.present? && end_at.end_of_day < next_date
    next_date
  end

  private

  # 複数プランを許容するなら削除する
  # Rspecも削除する
  def check_time_range
    plans = id.present? ? self.class.where.not(id: id) : self.class
    if end_at.present? && start_at >= end_at
      errors.add(:start_at, 'の値が間違っています。start_atはend_atより小さい値にしてください。')
    elsif ( tmp_plans = plans.where(billing_id: billing_id).where('( start_at <= ? AND ? <= end_at ) OR ( start_at <= ? AND end_at IS NULL )', start_at, start_at, start_at) ).present?
      errors.add(:start_at, "の値が間違っています。同じbilling_idで有効時間の範囲が被っています。#{tmp_plans.pluck(:id)}")
    elsif end_at.present? && ( tmp_plans = plans.where(billing_id: billing_id).where('( start_at <= ? AND ? <= end_at ) OR ( start_at <= ? AND end_at IS NULL )', end_at, end_at, end_at) ).present?
      errors.add(:end_at, "の値が間違っています。同じbilling_idで有効時間の範囲が被っています。#{tmp_plans.pluck(:id)}")
    elsif end_at.blank? && ( tmp_plans = plans.where(billing_id: billing_id).where('? <= start_at', start_at) ).present?
      errors.add(:start_at, "の値が間違っています。同じbilling_idで有効時間の範囲が被っています。#{tmp_plans.pluck(:id)}")
    end
  end

  def check_charge_date

    if type == 'weekly' && !%w(月 火 水 木 金 土 日).include?(charge_date)
      errors.add(:charge_date, 'の値が間違っています。typeが:weeklyの場合はcharge_dateは[月 火 水 木 金 土 日]のいずれかの値にしてください。')

    elsif type == 'monthly' && ( charge_date.to_i.to_s != charge_date || charge_date.to_i < 1 || 31 < charge_date.to_i )
      errors.add(:charge_date, 'の値が間違っています。typeが:monthlyの場合はcharge_dateは1~31の数値にしてください。')

    elsif type == 'annually' && !charge_date.match?(/\A\d{2}\/\d{2}\z/)
      errors.add(:charge_date, 'の値が間違っています。typeが:annuallyの場合はcharge_dateはMM/DDの値にしてください。')

    elsif type == 'annually' && charge_date.match?(/\A\d{2}\/\d{2}\z/)
      month = charge_date.split('/')[0].to_i
      date  = charge_date.split('/')[1].to_i

      if month < 1 || 12 < month || date < 1 || 31 < date
        errors.add(:charge_date, 'の値が間違っています。typeが:annuallyの場合はcharge_dateはMM/DDの値にしてください。')
        return
      end

      begin
        Time.zone.parse("#{Time.zone.now.strftime('%Y')}/#{charge_date}")
      rescue => e
        errors.add(:charge_date, 'の値が間違っています。typeが:annuallyの場合はcharge_dateはMM/DDの値にしてください。')
      end
    end
  end
end
