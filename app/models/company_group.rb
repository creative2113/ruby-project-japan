class CompanyGroup < ApplicationRecord
  self.inheritance_column = :_type_disabled # typeを使えるようにする

  CAPITAL = '資本金'.freeze
  EMPLOYEE = '従業員'.freeze
  SALES = '売上'.freeze
  RESERVED = { CAPITAL => 1000, EMPLOYEE => 1001, SALES => 1002 }.freeze
  NOT_OWN_CAPITALS = 'NOT_OWN_CAPITALS'.freeze

  has_many :company_company_groups
  has_many :companies, through: :company_company_groups

  enum type: [ :source, :group_company, :range, :classification ]

  validates :title, presence: true
  validates :grouping_number, presence: true
  validate :check_range
  validate :check_grouping_number_by_title

  private

  def check_range
    if type == 'range'
      if upper.blank? && lower.blank?
        if self.class.where(title: title, lower: nil, upper: nil).present? ||
           self.class.where(grouping_number: grouping_number, lower: nil, upper: nil).present?
          errors.add(:lower, 'の値が間違っています。既にlower=nil、upper=nilのレコードがあります。同じグループで作成できるのは一つだけです。')
        end
      elsif lower.blank? && upper.present?
        errors.add(:lower, 'の値が間違っています。lowerに値を入れてください。')

      elsif upper.present? && lower.to_i >= upper.to_i
        errors.add(:upper, 'の値が間違っています。upperはlowerより大きな値にしてください。')
      end

      if self.class.range.where('title = ? AND ? <= upper AND lower <= ? ', title, lower, upper).present? ||
         self.class.range.where('grouping_number = ? AND ? <= upper AND lower <= ? ', grouping_number, lower, upper).present?
        errors.add(:upper, 'の値が間違っています。他のレコードとレンジの範囲が被っています。')
      end
    else
      errors.add(:type, 'の値が間違っています。rangeではないですか？') if upper.present? || lower.present?
    end
  end

  def check_grouping_number_by_title
    return if self.class.where(title: title, subtitle: subtitle).blank?

    nums = self.class.where(title: title, subtitle: subtitle).where.not(id: id).pluck(:grouping_number).uniq

    return if nums.blank?

    if nums[0] != grouping_number
      errors.add(:grouping_number, "を既存のレコードと同じものにしてください。グループ番号 => #{nums[0]}")
    end
  end

  class << self
    def find_by_range(title, value)
      if value.blank?
        res = range.where('title = ? AND lower IS NULL AND upper IS NULL', title)
        return res.present? ? res[0] : nil
      end

      res = range.where('title = ? AND lower <= ? AND ? <= upper', title, value, value)
      return res[0] if res.present?

      res = range.where('title = ? AND lower <= ? AND upper IS NULL', title, value)
      res.present? ? res[0] : nil
    end

    def find_unknown(title)
      res = range.where('title = ? AND lower IS NULL AND upper IS NULL', title)
      return res.present? ? res[0] : nil
    end

    def groups_str(title, ids)
      return nil if ids.blank?

      ranges = range_combs(title).map do |group|
        next unless ids.include?(group[:id].to_s)
        group[:label]
      end

      ranges.compact
    end

    def range_combs(title)
      return {} if RESERVED[title].blank?

      ranges = range.where(grouping_number: RESERVED[title])

      return {} if ranges.blank?

      ranges.map do |r|
        label = if r.lower.blank? && r.upper.blank?
          '不明'
        elsif r.lower.present? && r.upper.blank?
          'それ以上'
        elsif r.upper / 1_000_000_000_000.0 >= 1.0
          "〜 #{(r.upper / 1_000_000_000_000).to_s(:delimited)}兆"
        elsif r.upper / 100_000_000.0 >= 1.0
          "〜 #{(r.upper / 100_000_000).to_s(:delimited)}億"
        elsif r.upper / 10_000.0 >= 1.0
          "〜 #{(r.upper / 10_000).to_s(:delimited)}万"
        else
          "〜 #{(r.upper).to_s(:delimited)}"
        end
        { id: r.id, lower: r.lower, upper: r.upper, label: label }
      end
    end

    def seed
      ranges = {CAPITAL => [[0, 1_000_000],
                            [1_000_001, 5_000_000],
                            [5_000_001, 10_000_000],
                            [10_000_001, 50_000_000],
                            [50_000_001, 100_000_000],
                            [100_000_001, 500_000_000],
                            [1_000_000_001, 5_000_000_000],
                            [5_000_000_001, 10_000_000_000],
                            [10_000_000_001, 50_000_000_000],
                            [50_000_000_001, 100_000_000_000],
                            [100_000_000_001, 500_000_000_000],
                            [500_000_000_001, 1_000_000_000_000],
                            [1_000_000_000_001, nil],
                            [nil, nil],
                           ],
                EMPLOYEE => [[0, 5],
                             [6, 10],
                             [11, 50],
                             [51, 100],
                             [101, 500],
                             [501, 1_000],
                             [1_001, 5_000],
                             [5_001, 10_000],
                             [10_001, 50_000],
                             [50_001, 100_000],
                             [100_001, 500_000],
                             [500_001, nil],
                             [nil, nil],
                            ],
                SALES => [[0, 10_000_000],
                          [10_000_001,  50_000_000],
                          [50_000_001, 100_000_000],
                          [100_000_001,   500_000_000],
                          [500_000_001, 1_000_000_000],
                          [1_000_000_001,  5_000_000_000],
                          [5_000_000_001, 10_000_000_000],
                          [10_000_000_001,  50_000_000_000],
                          [50_000_000_001, 100_000_000_000],
                          [100_000_000_001,   500_000_000_000],
                          [500_000_000_001, 1_000_000_000_000],
                          [1_000_000_000_001,  5_000_000_000_000],
                          [5_000_000_000_001, 10_000_000_000_000], # 10兆
                          [10_000_000_000_001,  50_000_000_000_000],
                          [50_000_000_000_001, 100_000_000_000_000],
                          [100_000_000_000_001, nil],
                          [nil, nil],
                         ],
               }

      ActiveRecord::Base.transaction do
        RESERVED.each do |k, v|
          next puts "#{k} SKIP" if where(title: k).present?
          ranges[k].each do |r|
            create!(type: types[:range], title: k, grouping_number: v, lower: r[0], upper: r[1])
          end
        end
      end
    end
  end
end
