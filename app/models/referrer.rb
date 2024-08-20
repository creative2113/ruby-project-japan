class Referrer < ApplicationRecord
  has_many :users

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
    cd = ''
    7.times do |_|
      cd = cd + SecureRandom.random_number(10).to_s
    end
    cd
  end
end
