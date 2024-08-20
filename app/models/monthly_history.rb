class MonthlyHistory < ApplicationRecord
  attr_reader :over, :added

  belongs_to :user

  validate :check

  def update_memo!(new_plan_num)
    tmp = Json2.parse(memo, symbolize: false) || {}
    tmp[plan] = Time.zone.now
    update!(plan: new_plan_num, memo: tmp.to_json)
  end

  def plan_code
    return :free if plan == EasySettings.plan[:free]
    return :administrator if plan == EasySettings.plan[:administrator]
    plan_name = PlanConverter.convert_to_plan(plan).name
    PlanConverter.convert_to_sym(plan_name)
  end

  def check
    user = User.find_by_id(user_id)

    if user.blank?
      errors.add(:user, 'ユーザは存在しません。')
      return
    end

    if start_at > end_at
      errors.add(:end_at, '終了期間は開始期間より後にしてください。')
      return
    end

    if self.class.get(user_id, start_at, id).present?
      errors.add(:start_at, '開始期間が被っています。')
    elsif self.class.get(user_id, end_at, id).present?
      errors.add(:end_at, '終了期間が被っています。')
    elsif self.class.where(user: user).where('? <= start_at AND end_at <= ?', start_at, end_at).where.not(id: id).present?
      errors.add(:start_at, '開始日と終了日の間の期間が被っています。')
    end
  end

  class << self
    def get(user, time = Time.zone.now, not_id = nil)
      q = where(user: user).where('start_at <= ? AND ? <= end_at', time, time)
      q = q.where.not(id: not_id) if not_id.present?
      q.first
    end

    # コンマ0秒のズレを考慮する
    def find_around(user, time = Time.zone.now)
      q1 = where(user: user).where('start_at <= ? AND ? <= end_at', time, time)
      q2 = where(user: user).where('start_at <= ? AND ? <= end_at', time + 1.second, time + 1.second)
      q3 = where(user: user).where('start_at <= ? AND ? <= end_at', time - 1.second, time - 1.second)

      if q1.size > 0
        q = q1
      elsif q2.size > 0
        q = q2
      elsif q3.size > 0
        q = q3
      else
        q = q1
      end
      q.first
    end

    def get_last(user)
      where(user: user).order(end_at: :desc).first
    end
  end
end
