class BanCondition < ApplicationRecord

  enum ban_action: [ :everywhere, :user_register, :inquiry ]

  def count_up
    self.with_lock do
      self.update!(count: self.count + 1, last_acted_at: Time.zone.now)
    end
  end

  class << self
    def find(id = nil, ip: nil, mail: nil, action: 0)
      return super(id) if id.present?

      return nil if ip.blank? && mail.blank?

      if mail.blank?
        where(ip: ip, ban_action: action)[0]
      elsif ip.blank?
        where(mail: mail, ban_action: action)[0]
      else
        where(ip: ip, ban_action: action).or(where(mail: mail, ban_action: action))[0]
      end
    end

    def ban?(ip: nil, mail: nil, action: 0)
      find(ip: ip, mail: mail, action: action).present?
    end
  end
end
