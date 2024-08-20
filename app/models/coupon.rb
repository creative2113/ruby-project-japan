class Coupon < ApplicationRecord
  has_many :user_coupons
  has_many :users, through: :user_coupons

  enum category: [ :trial_plan ]

  TRIAL_REFERRER_TITLE = '紹介者トライアル'.freeze

  validates :code, uniqueness: true

  before_validation :generate_code

  private

  def generate_code
    if code.blank?
      cd = ''
      1000.times do |_|
        cd = make_code
        break unless self.class.where(code: cd).exists?
      end

      self.code = cd
    end
  end

  def make_code
    SecureRandom.alphanumeric(11).to_s
  end

  class << self
    def find_referrer_trial
      self.find_by(title: TRIAL_REFERRER_TITLE)
    end
  end
end
